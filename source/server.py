#!/usr/bin/env python3

# Standard Library

from enum import Enum
from datetime import datetime, date
import sqlite3
import threading

# Third-party

from flask import Flask, request, jsonify

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
CREATE TABLE IF NOT EXISTS departures(
id INTEGER PRIMARY KEY AUTOINCREMENT,
operator_id INTEGER NOT NULL,
ferry_id INTEGER NOT NULL,
harbour_id INTEGER NOT NULL,
time DATETIME NOT NULL,
canceled INTEGER NOT NULL DEFAULT 0,
FOREIGN KEY (operator_id) REFERENCES users(id),
FOREIGN KEY (ferry_id) REFERENCES ferries(id),
FOREIGN KEY (harbour_id) REFERENCES harbours(id)
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS tickets(
id INTEGER PRIMARY KEY AUTOINCREMENT,
departure_id INTEGER NOT NULL,
customer_id INTEGER NOT NULL,
category TEXT NOT NULL,
FOREIGN KEY (departure_id) REFERENCES departures(id),
FOREIGN KEY (customer_id) REFERENCES users(id)
)
""")

connection.execute("""
CREATE TABLE IF NOT EXISTS persons(
id INTEGER PRIMARY KEY AUTOINCREMENT,
ticket_id INTEGER NOT NULL,
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

connection.commit()

# Presentation

app = Flask(__name__)

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

  query = "SELECT * FROM users WHERE id = ?"
  query_result = connection.execute(query, (id,))
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
    query = "SELECT * FROM ferries WHERE id = ?"
    query_result = connection.execute(query, (id,))
    result = (jsonify(query_result.fetchone()), 200)

  else:
    query = "SELECT * FROM ferries LIMIT ?"
    query_result = connection.execute(query, (limit,))
    result = (jsonify(query_result.fetchall()), 200)

  return result

@app.patch("/api/v1/ferries")
def patch_ferries():
  id = request.args.get("id", type=int)
  name = request.args.get("name", type=str)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

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
    query = "SELECT * FROM harbours WHERE id = ?"
    query_result = connection.execute(query, (id,))
    result = (jsonify(query_result.fetchone()), 200)

  else:
    query = "SELECT * FROM harbours LIMIT ?"
    query_result = connection.execute(query, (limit,))
    result = (jsonify(query_result.fetchall()), 200)

  return result
  
@app.patch("/api/v1/harbours")
def patch_harbours():
  id = request.args.get("id", type=int)
  name = request.args.get("name", type=str)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

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

# Depature

@app.post("/api/v1/departures")
def post_departure():
  operator_id = request.args.get("operator_id", type=int)
  ferry_id = request.args.get("ferry_id", type=int)
  harbour_id = request.args.get("harbour_id", type=int)
  time = request.args.get("time", type=datetime.fromisoformat)

  if operator_id is None:
    return jsonify(message="Missing or invalid operator_id"), 400

  if ferry_id is None:
    return jsonify(message="Missing or invalid ferry_id"), 400

  if harbour_id is None:
    return jsonify(message="Missing or invalid harbour_id"), 400

  if time is None:
    return jsonify(message="Missing or invalid time"), 400

  connection = get_connection()

  try:
    operator = connection.execute(
      "SELECT id FROM users WHERE id = ? AND role = 'operator'",
      (operator_id,)
    ).fetchone()

    if operator is None:
      raise ValueError("User does not exist or is not an operator")

    connection.execute(
      "INSERT INTO departures (operator_id, ferry_id, harbour_id, time) VALUES (?, ?, ?, ?)",
      (operator_id, ferry_id, harbour_id, time.isoformat())
    )

    connection.commit()

    result = jsonify(message="Departure created successfully"), 201

  except Exception as error:
    connection.rollback()

    result = jsonify(message=f"Failed to create departure: {str(error)}"), 400

  return result

@app.get("/api/v1/departures")
def get_departures():
  limit = request.args.get("limit", type=int, default=-1)

  connection = get_connection()

  query = "SELECT * FROM departures LIMIT ?"
  query_result = connection.execute(query, (limit,))
  result = (jsonify(query_result.fetchall()), 200)

  return result

@app.patch("/api/v1/departures")
def patch_departures():
  id = request.args.get("id", type=int)
  ferry_id = request.args.get("ferry_id", type=int)
  harbour_id = request.args.get("harbour_id", type=int)
  time = request.args.get("time", type=datetime.fromisoformat)
  canceled = request.args.get("canceled", type=int)

  if id is None:
    return jsonify(message="Missing or invalid id"), 400

  connection = get_connection()

  try:
    if ferry_id is not None:
      connection.execute("UPDATE departures SET ferry_id = ? WHERE id = ?", (ferry_id, id))

    if harbour_id is not None:
      connection.execute("UPDATE departures SET harbour_id = ? WHERE id = ?", (harbour_id, id))

    if time is not None:
      connection.execute("UPDATE departures SET time = ? WHERE id = ?", (time.isoformat(), id))

    if canceled is not None:
      connection.execute("UPDATE departures SET canceled = ? WHERE id = ?", (canceled, id))

    connection.commit()

    result = jsonify(message="Departure updated successfully"), 200

  except Exception as error:
    connection.rollback()
    
    result = jsonify(message=f"Failed to update departure: {str(error)}"), 400

  return result

# Ticket

class Variant(Enum):
  CAR = "car"
  TRUCK = "truck"
  BICYCLE = "bicycle"

@app.post("/api/v1/tickets")
def post_tickets():
  departure_id = request.args.get("departure_id", type=int)
  customer_id = request.args.get("customer_id", type=int)
  category = request.args.get("category", type=Category)
  birthday = request.args.get("birthday", type=  date.fromisoformat)
  variant = request.args.get("variant", type=Variant)
  identification = request.args.get("identification", type=str)

  if departure_id is None:
    return jsonify(message="Missing or invalid departure_id"), 400

  if customer_id is None:
    return jsonify(message="Missing or invalid customer_id"), 400

  if category is None:
    return jsonify(message="Missing or invalid category"), 400

  if category == Category.PERSON and birthday is None:
    return jsonify(message="Missing or invalid birthday"), 400

  if category == Category.VEHICLE:
    if variant is None:
      return jsonify(message="Missing or invalid variant"), 400

    if not identification:
      return jsonify(message="Missing identification"), 400

  connection = get_connection()

  try:
    cursor = connection.execute(
      "INSERT INTO tickets (departure_id, customer_id, category) VALUES (?, ?, ?)",
      (departure_id, customer_id, category.value)
    )

    ticket_id = cursor.lastrowid

    if category == Category.PERSON:
      connection.execute(
        "INSERT INTO persons (ticket_id, birthday) VALUES (?, ?)",
        (ticket_id, birthday)
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
  customer_id = request.args.get("customer_id", type=int)

  if customer_id is None:
    return jsonify(message="Error getting tickets, no customer id supplied"), 400

  connection = get_connection()

  query = """
    SELECT tickets.*, persons.birthday, vehicles.variant, vehicles.identification FROM tickets
    LEFT JOIN persons ON persons.ticket_id = tickets.id
    LEFT JOIN vehicles ON vehicles.ticket_id = tickets.id
    WHERE tickets.customer_id = ?
  """

  query_result = connection.execute(query, (customer_id,))
  result = (jsonify(query_result.fetchall()), 200)

  return result

# Main

app.run(debug=True)