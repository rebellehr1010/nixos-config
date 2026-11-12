"""Power-off safety checks; all plug and NAS communication is mocked."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("bay", Path(__file__).with_name("drive-bay.py"))
bay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bay)


class PowerControlTests(unittest.TestCase):
    def test_off_without_shutdown_assertion_never_contacts_plug(self):
        device = Mock()
        with self.assertRaisesRegex(RuntimeError, "requires --server-shut-down"):
            bay.control(device, "off")
        device.status.assert_not_called()
        device.set_status.assert_not_called()

    def test_live_server_blocks_power_off_even_with_assertion(self):
        device = Mock()
        with patch.object(bay, "server_responds", return_value=True):
            with self.assertRaisesRegex(RuntimeError, "still responds"):
                bay.control(device, "off", confirmed_shutdown=True)
        device.set_status.assert_not_called()

    def test_invalid_status_never_sends_power_command(self):
        device = Mock()
        device.status.return_value = {"Error": "Invalid key"}
        with self.assertRaisesRegex(RuntimeError, "authenticated relay status"):
            bay.control(device, "on")
        device.set_status.assert_not_called()

    def test_already_on_never_cycles_power(self):
        device = Mock()
        device.status.return_value = {"dps": {"1": True}}
        self.assertTrue(bay.control(device, "on"))
        device.set_status.assert_not_called()

    def test_status_does_not_write(self):
        device = Mock()
        device.status.return_value = {"dps": {"1": False}}
        self.assertFalse(bay.control(device, "status"))
        device.set_status.assert_not_called()

    def test_unconfirmed_state_change_is_failure(self):
        device = Mock()
        device.status.return_value = {"dps": {"1": False}}
        with patch.object(bay.time, "sleep"), self.assertRaisesRegex(RuntimeError, "did not confirm"):
            bay.control(device, "on")
        device.set_status.assert_called_once_with(True, switch=1)


if __name__ == "__main__":
    unittest.main()
