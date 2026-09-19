package com.astrakv.store;

public class StorageFullException extends RuntimeException {
    public StorageFullException(String message) {
        super(message);
    }
}
