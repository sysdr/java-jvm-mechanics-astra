#!/bin/bash
echo "--- AstraKV Build Lifecycle Starting ---"
if ! command -v mvn &> /dev/null; then
    echo "Error: Maven is not installed."
    exit 1
fi

echo "Cleaning and Compiling..."
mvn clean compile

echo "Running Test Suite..."
mvn test

echo "Verifying Engine Health..."
mvn exec:java -Dexec.mainClass="com.astrakv.core.EngineHealthCheck"

echo "--- Build and Verification Complete ---"