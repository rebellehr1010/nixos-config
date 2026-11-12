"""Check targeted key retrieval and temporary-session cleanup without network I/O."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("auth", Path(__file__).with_name("authorize-drive-bay.py"))
auth = importlib.util.module_from_spec(spec)
spec.loader.exec_module(auth)


class AuthorizationTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.folder = Path(temporary.name)
        for name in ("PENDING", "CONFIG", "QR"):
            p = patch.object(auth, name, self.folder / name)
            p.start()
            self.addCleanup(p.stop)
        auth.write_private(auth.PENDING, {"token": "test-qr", "user_code": "test-user", "created": auth.time.time()})
        auth.write_private(auth.CONFIG, {"device_id": auth.DEVICE_ID, "local_key": "", "address": "192.168.1.144", "version": 3.3})
        auth.QR.touch()
        self.login = self.mock("LoginControl")
        self.login.return_value.login_result.return_value = (True, {"endpoint": "https://example.invalid", "terminal_id": "temporary"})
        self.mock("CustomerTokenInfo")
        self.api = self.mock("CustomerApi").return_value
        self.user = self.mock("UserRepository").return_value

    def mock(self, name):
        p = patch.object(auth, name)
        self.addCleanup(p.stop)
        return p.start()

    def test_saves_only_confirmed_plug_key_and_revokes_session(self):
        self.api.get.return_value = {"success": True, "result": [{"id": auth.DEVICE_ID, "local_key": "0123456789abcdef"}]}
        auth.finish()
        self.api.get.assert_called_once_with("/v1.0/m/life/ha/devices/detail", {"devIds": auth.DEVICE_ID})
        config = json.loads(auth.CONFIG.read_text())
        self.assertEqual(config["local_key"], "0123456789abcdef")
        self.assertEqual(set(config), {"device_id", "address", "version", "local_key"})
        self.assertEqual(auth.CONFIG.stat().st_mode & 0o777, 0o600)
        self.user.unload.assert_called_once_with("temporary")
        self.assertFalse(auth.PENDING.exists())
        self.assertFalse(auth.QR.exists())

    def test_wrong_device_is_not_saved_and_session_is_revoked(self):
        self.api.get.return_value = {"success": True, "result": [{"id": "unrelated", "local_key": "0123456789abcdef"}]}
        with self.assertRaisesRegex(RuntimeError, "confirmed drive bay"):
            auth.finish()
        self.assertEqual(json.loads(auth.CONFIG.read_text())["local_key"], "")
        self.user.unload.assert_called_once_with("temporary")

    def test_pending_phone_approval_cannot_query_device_or_save_key(self):
        self.login.return_value.login_result.return_value = (False, {})
        with self.assertRaisesRegex(RuntimeError, "not complete"):
            auth.finish()
        self.api.get.assert_not_called()
        self.assertEqual(json.loads(auth.CONFIG.read_text())["local_key"], "")
        self.assertTrue(auth.PENDING.exists())


if __name__ == "__main__":
    unittest.main()
