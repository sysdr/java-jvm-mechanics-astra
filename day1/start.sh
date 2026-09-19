#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

# ANSI Color Codes for Professional CLI Dashboard Output
GREEN=$'\033[0;32m'
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m' # No Color

echo -e "${BLUE}${BOLD}======================================================================${NC}"
echo -e "${BLUE}${BOLD}               AstraKV Storage Engine Bootstrap (Day 1)               ${NC}"
echo -e "${BLUE}${BOLD}======================================================================${NC}"

# Step 1: Verify Prerequisites
echo -e "\n${CYAN}[1/5] Verifying system prerequisites...${NC}"
if ! command -v java &> /dev/null; then
    echo -e "${RED}Error: Java is not installed. Please install JDK 17 or higher.${NC}"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n 1 | awk -F '"' '{print $2}' | cut -d. -f1 || java -version 2>&1 | head -n 1 | grep -oE '[0-9]+' | head -n 1)
if [ "$JAVA_VERSION" -lt 17 ]; then
    echo -e "${YELLOW}Warning: AstraKV recommends JDK 17+. Detected version: $JAVA_VERSION${NC}"
fi
echo -e "${GREEN}✔ Java environment verified successfully (Version: $JAVA_VERSION).${NC}"

# Step 2: Create Project Structure and Source Files
echo -e "\n${CYAN}[2/5] Creating project structure and generating source code...${NC}"

mkdir -p src/com/astrakv/store
mkdir -p src/com/astrakv/test
mkdir -p bin

# Generate Exception Class
cat << 'EOF' > src/com/astrakv/store/StorageFullException.java
package com.astrakv.store;

public class StorageFullException extends RuntimeException {
    public StorageFullException(String message) {
        super(message);
    }
}
EOF

# Generate Entry Class
cat << 'EOF' > src/com/astrakv/store/Entry.java
package com.astrakv.store;

public class Entry {
    private final String key;
    private String value;
    private boolean deleted;

    public Entry(String key, String value) {
        this.key = key;
        this.value = value;
        this.deleted = false;
    }

    public String getKey() {
        return key;
    }

    public String getValue() {
        return value;
    }

    public void setValue(String value) {
        this.value = value;
    }

    public boolean isDeleted() {
        return deleted;
    }

    public void setDeleted(boolean deleted) {
        this.deleted = deleted;
    }
}
EOF

# Generate AstraKVStore Class
cat << 'EOF' > src/com/astrakv/store/AstraKVStore.java
package com.astrakv.store;

public class AstraKVStore {
    private final Entry[] entries;
    private final int capacity;
    private int size;

    public AstraKVStore(int capacity) {
        this.capacity = capacity;
        this.entries = new Entry[capacity];
        this.size = 0;
    }

    public synchronized void put(String key, String value) {
        if (key == null || value == null) {
            throw new IllegalArgumentException("Key and Value cannot be null");
        }

        // 1. Scan for existing active key or reusable deleted slot
        int firstDeletedIndex = -1;
        for (int i = 0; i < size; i++) {
            if (entries[i] != null) {
                if (entries[i].isDeleted() && firstDeletedIndex == -1) {
                    firstDeletedIndex = i;
                } else if (!entries[i].isDeleted() && key.equals(entries[i].getKey())) {
                    entries[i].setValue(value);
                    return;
                }
            }
        }

        // 2. Reuse soft-deleted slot if available
        if (firstDeletedIndex != -1) {
            entries[firstDeletedIndex] = new Entry(key, value);
            return;
        }

        // 3. Ensure we have physical capacity
        if (size >= capacity) {
            throw new StorageFullException("Store capacity reached: " + capacity);
        }

        // 4. Append to contiguous array
        entries[size] = new Entry(key, value);
        size++;
    }

    public synchronized String get(String key) {
        if (key == null) {
            throw new IllegalArgumentException("Key cannot be null");
        }

        for (int i = 0; i < size; i++) {
            if (entries[i] != null && !entries[i].isDeleted() && key.equals(entries[i].getKey())) {
                return entries[i].getValue();
            }
        }
        return null;
    }

    public synchronized boolean delete(String key) {
        if (key == null) {
            throw new IllegalArgumentException("Key cannot be null");
        }

        for (int i = 0; i < size; i++) {
            if (entries[i] != null && !entries[i].isDeleted() && key.equals(entries[i].getKey())) {
                entries[i].setDeleted(true); // Soft delete / Tombstone
                return true;
            }
        }
        return false;
    }

    public int getActiveSize() {
        int activeCount = 0;
        for (int i = 0; i < size; i++) {
            if (entries[i] != null && !entries[i].isDeleted()) {
                activeCount++;
            }
        }
        return activeCount;
    }

    public int getPhysicalSize() {
        return size;
    }

    public int getCapacity() {
        return capacity;
    }
}
EOF

# Generate CLI Class
cat << 'EOF' > src/com/astrakv/CLI.java
package com.astrakv;

import com.astrakv.store.AstraKVStore;
import com.astrakv.store.StorageFullException;
import java.util.Scanner;

public class CLI {
    private static final String GREEN = "\u001B[32m";
    private static final String RED = "\u001B[31m";
    private static final String RESET = "\u001B[0m";
    private static final String YELLOW = "\u001B[33m";
    private static final String CYAN = "\u001B[36m";

    public static void main(String[] args) {
        AstraKVStore store = new AstraKVStore(1000);
        Scanner scanner = new Scanner(System.in);

        System.out.println(CYAN + "==================================================" + RESET);
        System.out.println(CYAN + "       AstraKV Interactive Engine Terminal        " + RESET);
        System.out.println(CYAN + "==================================================" + RESET);
        System.out.println("Type 'help' to see available commands.");

        while (true) {
            System.out.print(CYAN + "astrakv> " + RESET);
            if (!scanner.hasNextLine()) break;
            String line = scanner.nextLine().trim();
            if (line.isEmpty()) continue;

            String[] tokens = line.split("\s+");
            String command = tokens[0].toLowerCase();

            try {
                switch (command) {
                    case "help":
                        printHelp();
                        break;
                    case "put":
                        if (tokens.length < 3) {
                            System.out.println(RED + "Error: Usage: put <key> <value>" + RESET);
                        } else {
                            long start = System.nanoTime();
                            store.put(tokens[1], tokens[2]);
                            long duration = System.nanoTime() - start;
                            System.out.println(GREEN + "OK (Latency: " + (duration / 1000.0) + " μs)" + RESET);
                        }
                        break;
                    case "get":
                        if (tokens.length < 2) {
                            System.out.println(RED + "Error: Usage: get <key>" + RESET);
                        } else {
                            long start = System.nanoTime();
                            String val = store.get(tokens[1]);
                            long duration = System.nanoTime() - start;
                            if (val != null) {
                                System.out.println(GREEN + "\"" + val + "\" (Latency: " + (duration / 1000.0) + " μs)" + RESET);
                            } else {
                                System.out.println(YELLOW + "(nil) (Latency: " + (duration / 1000.0) + " μs)" + RESET);
                            }
                        }
                        break;
                    case "del":
                        if (tokens.length < 2) {
                            System.out.println(RED + "Error: Usage: del <key>" + RESET);
                        } else {
                            long start = System.nanoTime();
                            boolean deleted = store.delete(tokens[1]);
                            long duration = System.nanoTime() - start;
                            if (deleted) {
                                System.out.println(GREEN + "OK (Latency: " + (duration / 1000.0) + " μs)" + RESET);
                            } else {
                                System.out.println(YELLOW + "(nil) (Latency: " + (duration / 1000.0) + " μs)" + RESET);
                            }
                        }
                        break;
                    case "stats":
                        System.out.println(CYAN + "--- Store Statistics ---" + RESET);
                        System.out.println("Active Keys:   " + store.getActiveSize());
                        System.out.println("Physical Keys: " + store.getPhysicalSize());
                        System.out.println("Max Capacity:  " + store.getCapacity());
                        break;
                    case "benchmark":
                        runBenchmark(store);
                        break;
                    case "exit":
                        System.out.println(GREEN + "Goodbye!" + RESET);
                        return;
                    default:
                        System.out.println(RED + "Unknown command. Type 'help' for usage." + RESET);
                }
            } catch (StorageFullException e) {
                System.out.println(RED + "Engine Error: Storage is full! " + e.getMessage() + RESET);
            } catch (Exception e) {
                System.out.println(RED + "Error: " + e.getMessage() + RESET);
            }
        }
    }

    private static void printHelp() {
        System.out.println("Commands:");
        System.out.println("  put <key> <value>   Insert or update a key-value pair");
        System.out.println("  get <key>           Retrieve value of a key");
        System.out.println("  del <key>           Delete a key-value pair (Soft Delete)");
        System.out.println("  stats               Display engine metrics");
        System.out.println("  benchmark           Run latency profile under linear scaling");
        System.out.println("  exit                Exit terminal");
    }

    private static void runBenchmark(AstraKVStore store) {
        System.out.println(YELLOW + "Running latency profile benchmark..." + RESET);
        int target = 800;
        long totalStart = System.currentTimeMillis();

        // Measure early phase latency
        long start1 = System.nanoTime();
        for (int i = 0; i < 100; i++) {
            store.put("b_key_" + i, "val_" + i);
        }
        long duration1 = System.nanoTime() - start1;

        // Fill engine to observe linear degradation
        for (int i = 100; i < target; i++) {
            store.put("b_key_" + i, "val_" + i);
        }

        // Measure late phase latency
        long start2 = System.nanoTime();
        for (int i = target; i < target + 100; i++) {
            try {
                store.put("b_key_" + i, "val_" + i);
            } catch (StorageFullException e) {
                break;
            }
        }
        long duration2 = System.nanoTime() - start2;
        long totalDuration = System.currentTimeMillis() - totalStart;

        System.out.println(GREEN + "✔ Benchmark complete!" + RESET);
        System.out.println("Early Phase Avg Latency (Low Occupancy):  " + (duration1 / 100000.0) + " μs/op");
        System.out.println("Late Phase Avg Latency (High Occupancy): " + (duration2 / 100000.0) + " μs/op");
        System.out.println("Total Benchmark Wall Time:               " + totalDuration + " ms");
        System.out.println(YELLOW + "Notice how latency increases as the linear scan array fills up!" + RESET);
    }
}
EOF

# Generate Test Class
cat << 'EOF' > src/com/astrakv/test/AstraKVTest.java
package com.astrakv.test;

import com.astrakv.store.AstraKVStore;
import com.astrakv.store.StorageFullException;

public class AstraKVTest {
    public static void main(String[] args) {
        System.out.println("Starting AstraKV Engine Verifications...");

        testBasicPutAndGet();
        testOverwriteKey();
        testSoftDeletionAndReclamation();
        testCapacityLimit();

        System.out.println("\u001B[32m✔ All AstraKV engine verifications passed successfully!u001B[0m");
    }

    private static void testBasicPutAndGet() {
        AstraKVStore store = new AstraKVStore(10);
        store.put("db_name", "AstraKV");
        assert "AstraKV".equals(store.get("db_name")) : "Failed basic storage lookup";
    }

    private static void testOverwriteKey() {
        AstraKVStore store = new AstraKVStore(10);
        store.put("version", "v1");
        store.put("version", "v2");
        assert "v2".equals(store.get("version")) : "Failed key overwrite update";
        assert store.getActiveSize() == 1 : "Size should remain 1 after overwrite";
    }

    private static void testSoftDeletionAndReclamation() {
        AstraKVStore store = new AstraKVStore(5);
        store.put("k1", "v1");
        store.put("k2", "v2");
        
        assert store.delete("k1") : "Deletion should return true";
        assert store.get("k1") == null : "Soft deleted key should return null";
        assert store.getActiveSize() == 1 : "Active size should be 1";
        assert store.getPhysicalSize() == 2 : "Physical size should remain 2";

        // Reclamation Test: next put should reuse the slot of k1
        store.put("k3", "v3");
        assert "v3".equals(store.get("k3")) : "Failed to insert new key after soft deletion";
        assert store.getPhysicalSize() == 2 : "Physical size should stay 2 due to slot reclamation";
    }

    private static void testCapacityLimit() {
        AstraKVStore store = new AstraKVStore(2);
        store.put("a", "1");
        store.put("b", "2");
        try {
            store.put("c", "3");
            throw new AssertionError("Failed to enforce capacity bounds");
        } catch (StorageFullException e) {
            // Expected
        }
    }
}
EOF

echo -e "${GREEN}✔ Project files successfully generated.${NC}"

# Step 3: Raw Compilation
echo -e "\n${CYAN}[3/5] Compiling source code via raw javac...${NC}"
javac -d bin src/com/astrakv/store/*.java src/com/astrakv/*.java src/com/astrakv/test/*.java
echo -e "${GREEN}✔ Compilation successful. Bytecode generated in bin/ directory.${NC}"

# Step 4: Run Unit Tests
echo -e "\n${CYAN}[4/5] Executing validation test suite...${NC}"
java -ea -cp bin com.astrakv.test.AstraKVTest
echo -e "${GREEN}✔ Unit tests passed successfully.${NC}"

# Step 5: Launch Interactive CLI
echo -e "\n${CYAN}[5/5] Launching AstraKV Interactive CLI Dashboard...${NC}"
echo -e "${YELLOW}Dashboard is launching. Enter your commands. To exit, type 'exit'.${NC}"
echo -e "${BLUE}----------------------------------------------------------------------${NC}"
java -cp bin com.astrakv.CLI