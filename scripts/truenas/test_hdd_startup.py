"""Safety checks for recovery decisions; never touches real storage."""

import importlib.util
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("startup", Path(__file__).with_name("hdd-startup.py"))
startup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(startup)
POOL = {"id": 18, "name": "HDDs", "guid": startup.GUID, "status": "OFFLINE"}
APP = {"id": 3, "name": "app_pool", "guid": "4220016969765961095"}


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.configured = self.mock("configured_pool", return_value=(POOL, [POOL, APP]))
        self.online = self.mock("already_online", return_value=False)
        self.imported = self.mock("imported_pools", return_value={"app_pool": (APP["guid"], "ONLINE")})
        self.api = self.mock("api", return_value=False)
        self.ready = self.mock("wait_for_disks")
        self.labels = self.mock("validate_labels")
        self.verify = self.mock("verify_available")

    def mock(self, name, **kwargs):
        p = patch.object(startup, name, **kwargs)
        self.addCleanup(p.stop)
        return p.start()

    def test_online_is_noop(self):
        self.online.return_value = True
        startup.recover()
        self.ready.assert_not_called()
        self.api.assert_not_called()
        self.verify.assert_called_once()

    def test_absent_drive_prevents_import(self):
        self.ready.side_effect = RuntimeError("missing member")
        with self.assertRaisesRegex(RuntimeError, "missing member"):
            startup.recover()
        self.assertEqual([c.args[0] for c in self.api.call_args_list], ["failover.licensed"])
        self.labels.assert_not_called()

    def test_bad_labels_prevent_import(self):
        self.labels.side_effect = RuntimeError("wrong pool")
        with self.assertRaisesRegex(RuntimeError, "wrong pool"):
            startup.recover()
        self.assertEqual(len(self.api.call_args_list), 1)

    def test_other_missing_pool_prevents_broad_import(self):
        self.imported.return_value = {}
        with self.assertRaisesRegex(RuntimeError, "Other registered pools"):
            startup.recover()
        self.ready.assert_not_called()

    def test_dry_run_never_imports(self):
        startup.recover(check_only=True)
        self.ready.assert_called_once_with(check_only=True)
        self.labels.assert_called_once()
        self.assertEqual(len(self.api.call_args_list), 1)
        self.verify.assert_not_called()

    def test_registration_change_prevents_import(self):
        self.configured.side_effect = [(POOL, [POOL, APP]), ({**POOL, "id": 19}, [POOL, APP])]
        with self.assertRaisesRegex(RuntimeError, "registration changed"):
            startup.recover()
        self.assertEqual(len(self.api.call_args_list), 1)

    def test_recovery_calls_boot_job_and_verifies(self):
        startup.recover()
        self.ready.assert_called_once()
        self.labels.assert_called_once()
        self.api.assert_any_call("pool.import_on_boot", job=True, timeout=180)
        self.verify.assert_called_once()

    def test_boot_job_failure_has_no_fallback(self):
        self.api.side_effect = [False, RuntimeError("method absent")]
        with self.assertRaisesRegex(RuntimeError, "method absent"):
            startup.recover()
        self.assertEqual(len(self.api.call_args_list), 2)
        self.verify.assert_not_called()

class DeviceValidationTests(unittest.TestCase):
    def test_cold_drive_uses_synchronous_start_on_generic_device(self):
        wwn = "50000c0f013a0c14"
        ready = [(False, "not ready (TUR 2)"), (True, "ready")]
        result = subprocess.CompletedProcess([], 0, "", "")
        with patch.object(startup, "DISKS", {wwn: startup.DISKS[wwn]}), \
                patch.object(startup, "disk_state", side_effect=ready), \
                patch.object(Path, "exists", return_value=True), \
                patch.object(startup, "scsi_device", return_value="/dev/sg4"), \
                patch.object(startup.time, "sleep"), \
                patch.object(startup, "run", return_value=result) as run:
            startup.wait_for_disks()
            run.assert_called_once_with(["sg_start", "--start", "/dev/sg4"], timeout=45, check=False)

    def test_preinit_does_not_start_services(self):
        with patch.object(startup, "api", return_value=False) as api:
            startup.refresh_live_shares()
            api.assert_called_once_with("system.ready")

    def test_live_recovery_only_reloads_running_shares(self):
        services = [{"service": "nfs", "state": "RUNNING"}, {"service": "cifs", "state": "STOPPED"}]
        with patch.object(startup, "api", side_effect=[True, services, None]) as api:
            startup.refresh_live_shares()
            self.assertEqual(len(api.call_args_list), 3)
            api.assert_any_call("service.control", "RELOAD", "nfs", job=True, timeout=60)

    def test_missing_device_check_does_not_start_or_rescan(self):
        with patch.object(startup, "disk_state", return_value=(False, "device not detected")), \
                patch.object(startup, "run") as run:
            with self.assertRaisesRegex(RuntimeError, "pool left untouched"):
                startup.wait_for_disks(check_only=True)
            run.assert_not_called()

    def test_imported_wrong_guid_or_degraded_is_refused(self):
        for value in (("123", "ONLINE"), (startup.GUID, "DEGRADED"), (startup.GUID, "SUSPENDED")):
            with self.subTest(value=value), patch.object(startup, "imported_pools", return_value={"HDDs": value}):
                with self.assertRaisesRegex(RuntimeError, "leaving it intact"):
                    startup.already_online()

    def test_label_pool_mismatch_is_refused(self):
        output = subprocess.CompletedProcess([], 0, stdout="    name: 'other'\n    pool_guid: 123\n")
        with patch.object(startup, "run", return_value=output):
            with self.assertRaisesRegex(RuntimeError, "Unexpected ZFS pool labels"):
                startup.validate_labels()

    def test_missing_mount_is_not_success(self):
        pool = {**POOL, "status": "ONLINE", "healthy": True}
        output = subprocess.CompletedProcess([], 0, stdout="boot-pool/ROOT/25.10.7/mnt\n")
        with patch.object(startup, "already_online", return_value=True), \
                patch.object(startup, "configured_pool", return_value=(pool, [pool, APP])), \
                patch.object(startup, "run", return_value=output):
            with self.assertRaisesRegex(RuntimeError, "not mounted"):
                startup.verify_available()


class PartitionDetectionTests(unittest.TestCase):
    def test_cold_disk_capacity_then_partition_detection(self):
        wwn = next(iter(startup.SAS))
        states = [(False, "not ready (TUR 2)"), (False, "kernel capacity is zero"), (True, "ready")]
        with patch.object(startup, "DISKS", {wwn: startup.DISKS[wwn]}), \
                patch.object(startup, "disk_state", side_effect=states), \
                patch.object(Path, "exists", return_value=True), \
                patch.object(Path, "write_text") as write, \
                patch.object(startup, "block_size", side_effect=[5860533168, 0]), \
                patch.object(startup, "scsi_device", return_value="/dev/sg4"), \
                patch.object(startup.time, "sleep"), \
                patch.object(startup, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as run:
            startup.wait_for_disks()
            commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual(commands[0], ["sg_start", "--start", "/dev/sg4"])
            self.assertIn(["blockdev", "--rereadpt", f"/dev/disk/by-id/wwn-0x{wwn}"], commands)
            self.assertEqual(sum(cmd[0] == "sg_start" for cmd in commands), 1)
            write.assert_called_once_with("1\n")

    def test_zero_capacity_never_opens_block_device(self):
        with patch.object(Path, "write_text"), \
                patch.object(startup, "block_size", return_value=0), \
                patch.object(startup, "run") as run:
            startup.refresh_kernel_disk(Path("/dev/sdx"), "expected-part")
            run.assert_called_once_with(["udevadm", "settle", "--timeout=10"], timeout=15)

    def test_existing_partition_does_not_reread_table(self):
        with patch.object(Path, "write_text"), \
                patch.object(startup, "block_size", return_value=1000), \
                patch.object(startup, "run") as run:
            startup.refresh_kernel_disk(Path("/dev/sdx"), "expected-part")
            run.assert_called_once_with(["udevadm", "settle", "--timeout=10"], timeout=15)

    def test_missing_partition_is_not_accepted_when_reread_fails(self):
        wwn = next(iter(startup.SAS))
        with patch.object(startup, "DISKS", {wwn: startup.DISKS[wwn]}), \
                patch.object(startup, "disk_state", return_value=(False, "pool partition missing or zero capacity")), \
                patch.object(Path, "exists", return_value=True), \
                patch.object(Path, "write_text"), \
                patch.object(startup, "block_size", side_effect=[5860533168, 0]), \
                patch.object(startup.time, "sleep"), \
                patch.object(startup.time, "monotonic", side_effect=[0, 0, 0, 1, 1, 1]), \
                patch.object(startup, "run", return_value=subprocess.CompletedProcess([], 1, "", "Device busy")) as run:
            with self.assertRaisesRegex(RuntimeError, "pool left untouched"):
                startup.wait_for_disks(timeout=1)
            self.assertFalse(any(call.args[0][0] in ("sg_start", "zpool", "midclt") for call in run.call_args_list))


class MonitorTests(unittest.TestCase):
    def setUp(self):
        fixture = Path(__file__).parent / "fixtures/hdds-online.json"
        self.healthy = json.loads(fixture.read_text())["pools"]["HDDs"]
        self.state = {"armed": True, "attempted": False, "attempts": [], "healthy_since": None}
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.state_path = self.mock("RUNTIME_STATE", Path(self.tempdir.name) / "runtime-state.json")
        self.run = self.mock("run", return_value=subprocess.CompletedProcess([], 0, "degraded\n", ""))
        self.load = self.mock("load_runtime_state", return_value=self.state)
        self.snapshot = self.mock("pool_snapshot", return_value=self.healthy)
        self.configured = self.mock("configured_pool", return_value=(POOL, [POOL, APP]))
        self.ready = self.mock("wait_for_disks")
        self.labels = self.mock("validate_labels")
        self.verify = self.mock("verify_available")
        self.shares = self.mock("refresh_live_shares")

    def mock(self, name, *args, **kwargs):
        p = patch.object(startup, name, *args, **kwargs)
        self.addCleanup(p.stop)
        return p.start()

    def suspended(self):
        pool = copy.deepcopy(self.healthy)
        pool["state"] = "SUSPENDED"
        for disk in startup.snapshot_devices(pool):
            disk["write_errors"] = 20
        return pool

    def assert_no_clear(self):
        self.assertFalse(any(call.args[0][:2] == ["zpool", "clear"] for call in self.run.call_args_list))

    def test_healthy_poll_does_not_touch_disks_or_clear_errors(self):
        self.state["armed"] = False
        startup.monitor()
        self.assertTrue(self.state["armed"])
        self.ready.assert_not_called()
        self.labels.assert_not_called()
        self.shares.assert_not_called()
        self.assert_no_clear()

    def test_exported_pool_is_not_imported(self):
        self.snapshot.return_value = None
        startup.monitor()
        self.assertFalse(self.state["armed"])
        self.ready.assert_not_called()
        self.configured.assert_not_called()
        self.assert_no_clear()

    def test_shutdown_is_untouched(self):
        self.run.return_value.stdout = "stopping\n"
        startup.monitor()
        self.snapshot.assert_not_called()
        self.assert_no_clear()

    def test_suspended_pool_recovers_only_after_readiness_and_labels(self):
        pool = self.suspended()
        self.snapshot.side_effect = [pool, pool, self.healthy]
        self.run.side_effect = lambda cmd, **kw: (
            subprocess.CompletedProcess([], 0, "degraded\n", "") if cmd[0] == "systemctl"
            else self.checked_clear(cmd))
        startup.monitor()
        self.ready.assert_called_once()
        self.labels.assert_called_once()
        self.verify.assert_called_once()
        self.shares.assert_called_once()
        self.assertTrue(self.state["attempted"])
        self.assertEqual(len(self.state["attempts"]), 1)

    def checked_clear(self, cmd):
        self.assertEqual(cmd, ["zpool", "clear", "HDDs"])
        saved = json.loads(Path(self.state_path).read_text())
        self.assertTrue(saved["attempted"])
        evidence = json.loads(Path(saved["last_evidence"]).read_text())
        self.assertEqual(evidence["before_clear"]["state"], "SUSPENDED")
        self.assertEqual(self.labels.call_count, 1)
        return subprocess.CompletedProcess([], 0, "", "")

    def test_offlined_member_is_untouched(self):
        pool = self.suspended()
        startup.snapshot_devices(pool)[0]["state"] = "OFFLINE"
        self.snapshot.return_value = pool
        with self.assertRaisesRegex(RuntimeError, "intentionally offlined"):
            startup.monitor()
        self.ready.assert_not_called()
        self.assert_no_clear()

    def test_checksum_errors_are_not_cleared(self):
        pool = self.suspended()
        startup.snapshot_devices(pool)[0]["checksum_errors"] = 1
        self.snapshot.return_value = pool
        with self.assertRaisesRegex(RuntimeError, "Data/checksum"):
            startup.monitor()
        self.assert_no_clear()

    def test_data_errors_are_not_cleared(self):
        pool = self.suspended()
        pool["error_count"] = 1
        self.snapshot.return_value = pool
        with self.assertRaisesRegex(RuntimeError, "Data/checksum"):
            startup.monitor()
        self.assert_no_clear()

    def test_unready_members_prevent_clear(self):
        self.snapshot.return_value = self.suspended()
        self.ready.side_effect = RuntimeError("enclosure still absent")
        with self.assertRaisesRegex(RuntimeError, "enclosure still absent"):
            startup.monitor()
        self.assertFalse(self.state["attempted"])
        self.assert_no_clear()

    def test_label_mismatch_prevents_clear(self):
        self.snapshot.return_value = self.suspended()
        self.labels.side_effect = RuntimeError("wrong pool label")
        with self.assertRaisesRegex(RuntimeError, "wrong pool label"):
            startup.monitor()
        self.assert_no_clear()

    def test_export_during_wait_prevents_clear(self):
        self.snapshot.side_effect = [self.suspended(), None]
        startup.monitor()
        self.assertFalse(self.state["armed"])
        self.assert_no_clear()

    def test_topology_change_prevents_clear(self):
        changed = self.suspended()
        startup.snapshot_devices(changed)[0]["path"] = "/dev/sdz1"
        self.snapshot.return_value = changed
        with self.assertRaisesRegex(RuntimeError, "topology differs"):
            startup.monitor()
        self.assert_no_clear()

    def test_wrong_identity_prevents_clear(self):
        changed = self.suspended()
        changed["pool_guid"] = 1
        self.snapshot.return_value = changed
        with self.assertRaisesRegex(RuntimeError, "identity mismatch"):
            startup.monitor()
        self.assert_no_clear()

    def test_no_baseline_prevents_clear(self):
        self.state["armed"] = False
        self.snapshot.return_value = self.suspended()
        with self.assertRaisesRegex(RuntimeError, "healthy baseline"):
            startup.monitor()
        self.assert_no_clear()

    def test_failed_clear_is_not_retried(self):
        self.snapshot.return_value = self.suspended()
        self.run.side_effect = [subprocess.CompletedProcess([], 0, "degraded\n", ""), RuntimeError("clear failed")]
        with self.assertRaisesRegex(RuntimeError, "clear failed"):
            startup.monitor()
        self.assertTrue(self.state["attempted"])
        self.run.side_effect = None
        self.run.return_value = subprocess.CompletedProcess([], 0, "degraded\n", "")
        with self.assertRaisesRegex(RuntimeError, "retry limit"):
            startup.monitor()
        self.assertEqual(self.ready.call_count, 1)

    def test_three_daily_attempts_require_manual_review(self):
        self.state["attempts"] = [1, 2, 3]
        self.snapshot.return_value = self.suspended()
        with self.assertRaisesRegex(RuntimeError, "retry limit"):
            startup.monitor()
        self.assert_no_clear()

    def test_single_failed_drive_is_not_treated_as_enclosure_loss(self):
        pool = copy.deepcopy(self.healthy)
        pool["state"] = "DEGRADED"
        startup.snapshot_devices(pool)[0]["state"] = "UNAVAIL"
        self.snapshot.return_value = pool
        with self.assertRaisesRegex(RuntimeError, "Not a suspended"):
            startup.monitor()
        self.assert_no_clear()


if __name__ == "__main__":
    unittest.main()
