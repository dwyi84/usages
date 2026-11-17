import base64
import json
import os
import unittest
from unittest import mock

from aiusages import secrets


class SecretParsingTests(unittest.TestCase):
    def test_parses_keyring_payload(self):
        token = {"access_token": "access", "refresh_token": "refresh", "expiry": "2026-11-17T14:44:10+09:00"}
        raw = json.dumps({"token": token, "auth_method": "consumer"})
        with mock.patch.object(secrets, "lookup", lambda service, username: raw):
            self.assertEqual(secrets.google_credentials(), token)

    def test_decodes_base64_prefix(self):
        token = {"access_token": "access", "refresh_token": "refresh"}
        encoded = "go-keyring-base64:" + base64.b64encode(json.dumps({"token": token}).encode()).decode()
        with mock.patch.object(secrets, "lookup", lambda service, username: encoded):
            self.assertEqual(secrets.google_credentials(), token)

    def test_rejects_garbage(self):
        with mock.patch.object(secrets, "lookup", lambda service, username: "not-json"):
            self.assertIsNone(secrets.google_credentials())
        with mock.patch.object(secrets, "lookup", lambda service, username: None):
            self.assertIsNone(secrets.google_credentials())

    def test_openrouter_key_prefers_keyring(self):
        with mock.patch.object(secrets, "lookup", lambda service, username: "  sk-or-keyring  "):
            with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": "sk-or-env"}):
                self.assertEqual(secrets.openrouter_key(), "sk-or-keyring")

    def test_openrouter_key_falls_back_to_env(self):
        with mock.patch.object(secrets, "lookup", lambda service, username: None):
            with mock.patch.dict(os.environ, {"OPENROUTER_API_KEY": "sk-or-env"}):
                self.assertEqual(secrets.openrouter_key(), "sk-or-env")

    def test_openrouter_key_missing(self):
        with mock.patch.object(secrets, "lookup", lambda service, username: None):
            with mock.patch.dict(os.environ, {}, clear=False):
                os.environ.pop("OPENROUTER_API_KEY", None)
                self.assertIsNone(secrets.openrouter_key())


if __name__ == "__main__":
    unittest.main()
