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

        System.out.println("\u001B[32m✔ All AstraKV engine verifications passed successfully!\u001B[0m");
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
