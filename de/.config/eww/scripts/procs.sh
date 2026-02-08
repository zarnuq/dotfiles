#!/bin/sh
ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu | head -6 | awk '{
  name=$2
  for(i=3; i<=NF-2; i++) name=name" "$i
  cpu=$(NF-1)
  mem=$NF
  gsub(/"/, "", name)
  printf "{\"pid\":\"%s\",\"name\":\"%s\",\"cpu\":\"%s\",\"mem\":\"%s\"}\n", $1, name, cpu, mem
}' | jq -sc '.'
