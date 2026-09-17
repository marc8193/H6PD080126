import sqlite3
import unittest

import server

class Server_Test(unittest.TestCase):
  def setUp(self):
    server.app.config["DATABASE"] = ":memory:"

    self.connection = server.get_connection()

    server.create_tables(self.connection)

    server.app.config["TESTING"] = True
    self.client = server.app.test_client()

  def tearDown(self):
    self.connection.close()

    if hasattr(server.thread_local, "connection"):
      del server.thread_local.connection

  def test_post_user(self):
    response = self.client.post(
      "/api/v1/users",
      query_string={
        "role": "customer",
        "name": "Test User",
        "email": "test@example.com",
      },
    )

    self.assertEqual(response.status_code, 201)

    user = self.connection.execute("SELECT * FROM users").fetchone()

    self.assertEqual(user["role"], "customer")
    self.assertEqual(user["name"], "Test User")
    self.assertEqual(user["email"], "test@example.com")

if __name__ == "__main__":
  unittest.main()