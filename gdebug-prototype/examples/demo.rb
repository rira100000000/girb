#!/usr/bin/env ruby
# frozen_string_literal: true

# Demo script for gdebug
# Run with: rdbg -r gdebug examples/demo.rb

require_relative "../lib/gdebug"

class User
  attr_accessor :name, :email, :age

  def initialize(name:, email:, age:)
    @name = name
    @email = email
    @age = age
  end

  def adult?
    age >= 18
  end

  def greeting
    "Hello, #{name}!"
  end
end

def process_users(users)
  adults = users.select(&:adult?)
  debugger  # Try: ai "How many adults are there?"
  adults.map(&:greeting)
end

# Sample data
users = [
  User.new(name: "Alice", email: "alice@example.com", age: 25),
  User.new(name: "Bob", email: "bob@example.com", age: 17),
  User.new(name: "Charlie", email: "charlie@example.com", age: 30)
]

result = process_users(users)
puts result
