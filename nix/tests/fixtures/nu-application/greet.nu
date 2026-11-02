#!/usr/bin/env nu

def main [name: string] {
  $"hello, ($name)" | ^rg hello
}
