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
