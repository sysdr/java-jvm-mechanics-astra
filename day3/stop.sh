#!/bin/bash
echo "--- Cleaning Runtime Artifacts ---"
mvn clean
rm -rf target/
echo "Cleanup finished."