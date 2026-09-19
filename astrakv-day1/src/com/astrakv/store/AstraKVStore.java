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
