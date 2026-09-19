package com.astrakv.core;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class AstraKVStoreTest {

    @Test
    void putAndGetRoundTrip() {
        AstraKVStore store = new AstraKVStore(8);
        store.put("health", "ok");
        assertEquals("ok", store.get("health"));
        assertEquals(1, store.size());
    }

    @Test
    void missingKeyReturnsNull() {
        AstraKVStore store = new AstraKVStore(8);
        assertNull(store.get("missing"));
    }
}
