package com.astrakv.core;

import java.util.Objects;

public class AstraKVStore {
    private final String[] keys;
    private final String[] values;
    private final int capacity;
    private int size;

    public AstraKVStore(int capacity) {
        if (capacity < 1) {
            throw new IllegalArgumentException("Capacity must be positive");
        }
        this.capacity = capacity;
        this.keys = new String[capacity];
        this.values = new String[capacity];
        this.size = 0;
    }

    public void put(String key, String value) {
        Objects.requireNonNull(key, "key");
        Objects.requireNonNull(value, "value");
        for (int i = 0; i < size; i++) {
            if (key.equals(keys[i])) {
                values[i] = value;
                return;
            }
        }
        if (size >= capacity) {
            throw new IllegalStateException("Store capacity reached: " + capacity);
        }
        keys[size] = key;
        values[size] = value;
        size++;
    }

    public String get(String key) {
        Objects.requireNonNull(key, "key");
        for (int i = 0; i < size; i++) {
            if (key.equals(keys[i])) {
                return values[i];
            }
        }
        return null;
    }

    public int size() {
        return size;
    }
}
