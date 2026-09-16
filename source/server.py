#!/usr/bin/env python3

# Standard Library

from datetime import datetime, date
from enum import Enum
import sqlite3
import threading

# Third-party

from flask import Flask, request, jsonify
from flask_cors import CORS

# Storage

thread_local = threading.local()

def dict_factory(cursor, row):
  fields = [column[0] for column in cursor.description]
  return {key: value for key, value in zip(fields, row)}

def get_connection():
  if not hasattr(thread_local, "connection"):
    connection = sqlite3.connect("build/booking.db")
    connection.row_factory = dict_factory
    connection.execute("PRAGMA foreign_keys = ON")

    thread_local.connection = connection

  return thread_local.connection

connection = get_connection()

connection.execute("""
CREATE TABLE IF NOT EXISTS users(
id INTEGER PRIMARY KEY AUTOINCREMENT,
role TEXT NOT NULL,
name TEXT NOT NULL,
email TEXT NOT NULL
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS ferries(
id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT NOT NULL
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS harbours(
id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT NOT NULL
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS capacities(
id INTEGER PRIMARY KEY AUTOINCREMENT,
ferry_id INTEGER NOT NULL,
category TEXT NOT NULL,
maximum INTEGER NOT NULL,
FOREIGN KEY (ferry_id) REFERENCES ferries(id)
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS stops(
id INTEGER PRIMARY KEY AUTOINCREMENT,
user_id INTEGER NOT NULL,
ferry_id INTEGER NOT NULL,
harbour_id INTEGER NOT NULL,
zone TEXT NOT NULL,
start INTEGER NOT NULL,
canceled INTEGER NOT NULL DEFAULT 0,
FOREIGN KEY (user_id) REFERENCES users(id),
FOREIGN KEY (ferry_id) REFERENCES ferries(id),
FOREIGN KEY (harbour_id) REFERENCES harbours(id)
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS tickets(
id INTEGER PRIMARY KEY AUTOINCREMENT,
user_id INTEGER NOT NULL,
category TEXT NOT NULL,
FOREIGN KEY (user_id) REFERENCES users(id)
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS persons(
id INTEGER PRIMARY KEY AUTOINCREMENT,
ticket_id INTEGER NOT NULL,
firstname TEXT NOT NULL,
lastname TEXT NOT NULL,
birthday DATE NOT NULL,
FOREIGN KEY (ticket_id) REFERENCES tickets(id)
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS vehicles(
id INTEGER PRIMARY KEY AUTOINCREMENT,
ticket_id INTEGER NOT NULL,
variant TEXT NOT NULL,
identification TEXT NOT NULL,
FOREIGN KEY (ticket_id) REFERENCES tickets(id)
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS stops_tickets(
id INTEGER PRIMARY KEY AUTOINCREMENT,
stop_id INTEGER NOT NULL,
ticket_id INTEGER NOT NULL,
FOREIGN KEY (stop_id) REFERENCES stops(id)
FOREIGN KEY (ticket_id) REFERENCES tickets(id)
)
""")

connection.commit()

# Presentation

app = Flask(__name__)

CORS(app, origins=["http://localhost:8000"])

## User

class Role(Enum):
  CUSTOMER = "customer"
  OPERATOR = "operator"

@app.post("/api/v1/users")
def post_users():
  role = request.args.get("role", type=Role)
  name = request.args.get("name", type=str)
  email = request.args.get("email", type=str)

  if role is None:
    return jsonify(message="Missing or invalid role"), 400

  if name is None:
    return jsonify(message="Missing name"), 400

  if email is None:
    return jsonify(message="Missing email"), 400

  connection = get_connection()

  try:
    connection.execute(
      "INSERT INTO users (role, name, email) VALUES (?, ?, ?)",
      (role.value, name, email)
    )

    connection.commit()

    result = (jsonify(message="User created successfully"), 201)

  except Exception as error:
    connection.rollback()

    result = (jsonify(message=f"Failed to create user: {str(error)}"), 400)

  return result

@app.get("/api/v1/users")
def get_users():
  id = request.args.get("id", type=int)

  if "id" in request.args and id is None:
    return jsonify(message="Invalid id"), 400

  if id is None:
    return jsonify(message="Missing id"), 400

  connection = get_connection()

  query_result = connection.execute("SELECT * FROM users WHERE id = ?", (id,))
  result = (jsonify(query_result.fetchone()), 200)

  return result

@app.patch("/api/v1/users")
def patch_users():
  id = request.args.get("id", type=int)
  role = request.args.get("role", type=Role)
  name = request.args.get("name", type=str)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

  connection = get_connection()

  try:
    if role is not None:
      connection.execute("UPDATE users SET role = ? WHERE id = ?", (role.value, id))

    if name is not None:
      connection.execute("UPDATE users SET name = ? WHERE id = ?", (name, id))

    connection.commit()

    result = jsonify(message="User updated successfully"), 200

  except Exception as error:
    connection.rollback()

    result = jsonify(message=f"Failed to update user: {str(error)}"), 400

  return result

## Ferry

@app.post("/api/v1/ferries")
def post_ferries():
  name = request.args.get("name", type=str)

  if name is None:
    return jsonify(message="Missing name"), 400

  connection = get_connection()

  try:
    connection.execute("INSERT INTO ferries (name) VALUES (?)", (name,))
    connection.commit()

    result = (jsonify(message="Ferry created successfully"), 201)

  except Exception as error:
    connection.rollback()

    result = (jsonify(message=f"Failed to create ferry: {str(error)}"), 400)

  return result

@app.get("/api/v1/ferries")
def get_ferries():
  id = request.args.get("id", type=int)
  limit = request.args.get("limit", type=int, default=-1)

  if "id" in request.args and id is None:
    return jsonify(message="Invalid id"), 400

  if "limit" in request.args and limit is None:
    return jsonify(message="Invalid limit"), 400

  connection = get_connection()

  if id is not None:
    query_result = connection.execute("SELECT * FROM ferries WHERE id = ?", (id,))

  else:
    query_result = connection.execute("SELECT * FROM ferries LIMIT ?", (limit,))

  result = (jsonify(query_result.fetchall()), 200)

  return result

@app.patch("/api/v1/ferries")
def patch_ferries():
  id = request.args.get("id", type=int)
  name = request.args.get("name", type=str)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

  if name is None:
    return jsonify(message="Missing or invalid name"), 400

  connection = get_connection()

  try:
    if name is not None:
      connection.execute("UPDATE ferries SET name = ? WHERE id = ?", (name, id))

    connection.commit()

    result = jsonify(message="Ferry updated successfully"), 200

  except Exception as error:
    connection.rollback()

    result = jsonify(message=f"Failed to update ferry: {str(error)}"), 400

  return result

## Ferry Capacity

class Category(Enum):
  PERSON = "person"
  PET = "pet"
  BREAKFAST = "breakfast"
  FIRSTCLASS = "firstclass"
  VEHICLE = "vehicle"

@app.post("/api/v1/ferries/capacities")
def post_ferry_capacities():
  ferry_id = request.args.get("ferry_id", type=int)
  category = request.args.get("category", type=Category)
  maximum = request.args.get("maximum", type=int)

  if ferry_id is None:
    return jsonify(message="Missing or invalid ferry_id"), 400

  if category is None:
    return jsonify(message="Missing or invalid category"), 400

  if maximum is None:
    return jsonify(message="Missing or invalid maximum"), 400

  connection = get_connection()

  try:
    connection.execute(
      "INSERT INTO capacities (ferry_id, category, maximum) VALUES (?, ?, ?)",
      (ferry_id, category.value, maximum)
    )

    connection.commit()

    result = (jsonify(message="Capacity created successfully"), 201)

  except Exception as error:
    connection.rollback()

    result = (jsonify(message=f"Failed to create capacity: {str(error)}"), 400)

  return result

@app.get("/api/v1/ferries/capacities")
def get_ferry_capacities():
  ferry_id = request.args.get("ferry_id", type=int)

  if ferry_id is None:
    return jsonify(message="Missing or invalid ferry_id"), 400

  connection = get_connection()

  query = "SELECT * FROM capacities WHERE ferry_id = ?"
  query_result = connection.execute(query, (ferry_id,))
  result = (jsonify(query_result.fetchall()), 200)

  return result

@app.patch("/api/v1/ferries/capacities")
def patch_ferry_capacities():
  id = request.args.get("id", type=int)
  category = request.args.get("category", type=Category)
  maximum = request.args.get("maximum", type=int)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

  connection = get_connection()

  try:
    if category is not None:
      connection.execute("UPDATE capacities SET category = ? WHERE id = ?", (category.value, id))

    if maximum is not None:
      connection.execute("UPDATE capacities SET maximum = ? WHERE id = ?", (maximum, id))

    connection.commit()

    result = jsonify(message="Capacity updated successfully"), 200

  except Exception as error:
    connection.rollback()

    result = jsonify(message=f"Failed to update capacity: {str(error)}"), 400

  return result

## Harbour

@app.post("/api/v1/harbours")
def post_harbours():
  name = request.args.get("name", type=str)

  if name is None:
    return jsonify(message="Missing name"), 400

  connection = get_connection()

  try:
    connection.execute("INSERT INTO harbours (name) VALUES (?)", (name,))
    connection.commit()

    result = (jsonify(message="Harbour created successfully"), 201)

  except Exception as error:
    connection.rollback()

    result = (jsonify(message=f"Failed to create harbour: {str(error)}"), 400)

  return result

@app.get("/api/v1/harbours")
def get_harbours():
  id = request.args.get("id", type=int)
  limit = request.args.get("limit", type=int, default=-1)

  if "id" in request.args and id is None:
    return jsonify(message="Invalid id"), 400

  if "limit" in request.args and limit is None:
    return jsonify(message="Invalid limit"), 400

  connection = get_connection()

  if id is not None:
    query_result = connection.execute("SELECT * FROM harbours WHERE id = ?", (id,))

  else:
    query_result = connection.execute("SELECT * FROM harbours LIMIT ?", (limit,))

  result = (jsonify(query_result.fetchall()), 200)

  return result

@app.patch("/api/v1/harbours")
def patch_harbours():
  id = request.args.get("id", type=int)
  name = request.args.get("name", type=str)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

  if name is None:
    return jsonify(message="Missing or invalid name"), 400

  connection = get_connection()

  try:
    if name is not None:
      connection.execute("UPDATE harbours SET name = ? WHERE id = ?", (name, id))

    connection.commit()

    result = jsonify(message="Harbour updated successfully"), 200

  except Exception as error:
    connection.rollback()

    result = jsonify(message=f"Failed to update harbour: {str(error)}"), 400

  return result

# Stop

@app.post("/api/v1/stops")
def post_stops():
  user_id = request.args.get("user_id", type=int)
  ferry_id = request.args.get("ferry_id", type=int)
  harbour_id = request.args.get("harbour_id", type=int)
  zone = request.args.get("zone", type=str)
  start = request.args.get("start", type=int)

  if user_id is None:
    return jsonify(message="Missing or invalid user_id"), 400

  if ferry_id is None:
    return jsonify(message="Missing or invalid ferry_id"), 400

  if harbour_id is None:
    return jsonify(message="Missing or invalid harbour_id"), 400

  if zone is None:
    return jsonify(message="Missing or invalid zone"), 400

  if start is None:
    return jsonify(message="Missing or invalid start"), 400

  connection = get_connection()

  try:
    stop = connection.execute(
      """
      INSERT INTO stops (user_id, ferry_id, harbour_id, zone, start)
      SELECT id, ?, ?, ?, ?
      FROM users
      WHERE id = ? AND role = 'operator'
      RETURNING id
      """,
      (ferry_id, harbour_id, zone, start, user_id)
    ).fetchone()

    if stop is None:
      raise ValueError("User does not exist or is not an operator")

    connection.commit()

    result = jsonify(message="Stop created successfully"), 201

  except Exception as error:
    connection.rollback()

    result = jsonify(message=f"Failed to create stop: {str(error)}"), 400

  return result

@app.get("/api/v1/stops")
def get_stops():
  harbour_id = request.args.get("harbour_id", type=int)
  limit = request.args.get("limit", type=int, default=-1)

  if harbour_id is None:
    return jsonify(message="Missing or invalid harbour_id"), 400

  connection = get_connection()

  query = """
    SELECT
      stops.*,
      users.id AS user_id,
      users.role AS user_role,
      users.name AS user_name,
      users.email AS user_email,
      ferries.id AS ferry_id,
      ferries.name AS ferry_name,
      harbours.id AS harbour_id,
      harbours.name AS harbour_name
    FROM stops
    INNER JOIN users ON users.id = stops.user_id
    INNER JOIN ferries ON ferries.id = stops.ferry_id
    INNER JOIN harbours ON harbours.id = stops.harbour_id
    WHERE stops.harbour_id = ?
    LIMIT ?
  """

  query_result = connection.execute(query, (harbour_id, limit))

  try:
    stops = []

    for row in query_result.fetchall():
      stop = {
        "id": row["id"],
        "zone": row["zone"],
        "start": row["start"],
        "canceled": bool(row["canceled"]),
        "user": {
          "id": row["user_id"],
          "role": row["user_role"],
          "name": row["user_name"],
          "email": row["user_email"],
        },
        "ferry": {
          "id": row["ferry_id"],
          "name": row["ferry_name"],
        },
        "harbour": {
          "id": row["harbour_id"],
          "name": row["harbour_name"],
        },
      }

      stops.append(stop)

    for stop in stops:
      query = """
        SELECT
          capacities.id,
          capacities.category,
          capacities.maximum
        FROM capacities
        WHERE capacities.ferry_id = ?
        LIMIT ?
      """

      query_result = connection.execute(query, (stop["ferry"]["id"], limit))

      for row in query_result.fetchall():
        stop["ferry"].setdefault("capacities", []).append(dict(row))

    result = jsonify(stops), 200

  except Exception as error:
    result = jsonify(message=str(error)), 400

  return result

@app.patch("/api/v1/stops")
def patch_stops():
  id = request.args.get("id", type=int)
  ferry_id = request.args.get("ferry_id", type=int)
  harbour_id = request.args.get("harbour_id", type=int)
  zone = request.args.get("zone", type=str)
  start = request.args.get("start", type=int)
  canceled = request.args.get("canceled", type=str)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

  if canceled is not None:
    canceled = canceled.lower() == "true"

  connection = get_connection()

  try:
    if ferry_id is not None:
      connection.execute("UPDATE stops SET ferry_id = ? WHERE id = ?", (ferry_id, id))

    if harbour_id is not None:
      connection.execute("UPDATE stops SET harbour_id = ? WHERE id = ?", (harbour_id, id))

    if zone is not None:
      connection.execute("UPDATE stops SET zone = ? WHERE id = ?", (zone, id))

    if start is not None:
      connection.execute("UPDATE stops SET start = ? WHERE id = ?", (start, id))

    if canceled is not None:
      connection.execute("UPDATE stops SET canceled = ? WHERE id = ?", (canceled, id))

    connection.commit()

    result = jsonify(message="stop updated successfully"), 200

  except Exception as error:
    connection.rollback()

    result = jsonify(message=f"Failed to update stop: {str(error)}"), 400

  return result

# Ticket

class Variant(Enum):
  CAR = "car"
  TRUCK = "truck"
  BICYCLE = "bicycle"

@app.post("/api/v1/tickets")
def post_tickets():
  stop_ids = request.args.getlist("stop_ids", type=int)
  user_id = request.args.get("user_id", type=int)
  category = request.args.get("category", type=Category)
  firstname = request.args.get("firstname", type=str)
  lastname = request.args.get("lastname", type=str)
  birthday = request.args.get("birthday", type=date.fromisoformat)
  variant = request.args.get("variant", type=Variant)
  identification = request.args.get("identification", type=str)

  if len(stop_ids) < 2:
    return jsonify(message="At least two stop_ids are required"), 400

  if user_id is None:
    return jsonify(message="Missing or invalid user_id"), 400

  if category is None:
    return jsonify(message="Missing or invalid category"), 400

  if category == Category.PERSON:
    if firstname is None:
      return jsonify(message="Missing or invalid firstname"), 400

    if lastname is None:
      return jsonify(message="Missing or invalid lastname"), 400

    if birthday is None:
      return jsonify(message="Missing or invalid birthday"), 400

  if category == Category.VEHICLE:
    if variant is None:
      return jsonify(message="Missing or invalid variant"), 400

    if not identification:
      return jsonify(message="Missing identification"), 400

  connection = get_connection()

  try:
    cursor = connection.execute(
      "INSERT INTO tickets (user_id, category) VALUES (?, ?)",
      (user_id, category.value)
    )

    ticket_id = cursor.lastrowid

    for stop_id in stop_ids:
      connection.execute(
        "INSERT INTO stops_tickets (stop_id, ticket_id) VALUES (?, ?)",
        (stop_id, ticket_id)
      )

    if category == Category.PERSON:
      connection.execute(
        "INSERT INTO persons (ticket_id, firstname, lastname, birthday) VALUES (?, ?, ?, ?)",
        (ticket_id, firstname, lastname, birthday)
      )

    elif category == Category.VEHICLE:
      connection.execute(
        "INSERT INTO vehicles (ticket_id, variant, identification) VALUES (?, ?, ?)",
        (ticket_id, variant.value, identification)
      )

    connection.commit()

    return jsonify(message="Ticket created successfully"), 201

  except Exception as error:
    connection.rollback()

    return jsonify(message=f"Error creating ticket: {str(error)}"), 400

@app.get("/api/v1/tickets")
def get_tickets():
  id = request.args.get("id", type=int)
  user_id = request.args.get("user_id", type=int)

  if id is None and user_id is None:
    return jsonify(message="Missing or invalid id or user_id"), 400

  connection = get_connection()

  query = """
    SELECT
      tickets.id,
      tickets.category,
      persons.birthday,
      persons.firstname,
      persons.lastname,
      vehicles.variant,
      vehicles.identification,
      users.id AS user_id,
      users.name AS user_name,
      users.email AS user_email,
      users.role AS user_role
    FROM tickets
    INNER JOIN users ON users.id = tickets.user_id
    LEFT JOIN persons ON persons.ticket_id = tickets.id
    LEFT JOIN vehicles ON vehicles.ticket_id = tickets.id
  """

  if id is not None:
    query += " WHERE tickets.id = ?"
    value = id

  else:
    query += " WHERE tickets.user_id = ?"
    value = user_id

  tickets = []

  try:
    for row in connection.execute(query, (value,)).fetchall():
      ticket = {
        "id": row["id"],
        "category": row["category"],
        "stops": [],
        "user": {
          "id": row["user_id"],
          "name": row["user_name"],
          "email": row["user_email"],
          "role": row["user_role"],
        },
      }

      query = """
        SELECT stops.*
        FROM stops
        INNER JOIN stops_tickets ON stops_tickets.stop_id = stops.id
        WHERE stops_tickets.ticket_id = ?
      """

      stops = connection.execute(query, (row["id"],)).fetchall()
      for stop in stops:
        ticket["stops"].append({
          "id": stop["id"],
          "zone": stop["zone"],
          "start": stop["start"] }
        )

      if row["firstname"] is not None:
        ticket["person"] = {
          "firstname": row["firstname"],
          "lastname": row["lastname"],
          "birthday": row["birthday"],
        }

      if row["variant"] is not None:
        ticket["vehicle"] = {
          "variant": row["variant"],
          "identification": row["identification"],
        }

      tickets.append(ticket)

  except Exception as error:
    return jsonify(message=str(error)), 400

  return jsonify(tickets), 200

# Main

app.run(debug=True)