package com.astrakv.core;

public class EngineHealthCheck {
    public static void main(String[] args) {
        AstraKVStore store = new AstraKVStore(16);
        store.put("engine", "AstraKV");
        store.put("status", "ok");

        if (!"AstraKV".equals(store.get("engine")) || !"ok".equals(store.get("status"))) {
            System.err.println("FAIL: AstraKV engine health check failed");
            System.exit(1);
        }

        System.out.println("OK: AstraKV engine is healthy");
        System.out.println("activeKeys=" + store.size());
    }
}
