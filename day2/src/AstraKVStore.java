import java.util.Objects;

/**
 * Open-addressing hash table with linear probing so colliding keys
 * (same hashCode, same bucket) remain independently retrievable.
 */
public class AstraKVStore {
    private final Entry[] table;
    private final int capacity;
    private int size;

    public AstraKVStore(int capacity) {
        if (capacity < 1) {
            throw new IllegalArgumentException("Capacity must be positive");
        }
        this.capacity = capacity;
        this.table = new Entry[capacity];
        this.size = 0;
    }

    public int bucket(String key) {
        return Math.floorMod(key.hashCode(), capacity);
    }

    public void put(String key, String value) {
        Objects.requireNonNull(key, "key");
        Objects.requireNonNull(value, "value");

        int start = bucket(key);
        int firstTombstone = -1;

        for (int i = 0; i < capacity; i++) {
            int idx = (start + i) % capacity;
            Entry e = table[idx];

            if (e == null) {
                int target = firstTombstone != -1 ? firstTombstone : idx;
                table[target] = new Entry(key, value);
                size++;
                return;
            }

            if (e.isDeleted()) {
                if (firstTombstone == -1) {
                    firstTombstone = idx;
                }
                continue;
            }

            if (key.equals(e.getKey())) {
                e.setValue(value);
                return;
            }
        }

        if (firstTombstone != -1) {
            table[firstTombstone] = new Entry(key, value);
            size++;
            return;
        }

        throw new IllegalStateException("Store capacity reached: " + capacity);
    }

    public String get(String key) {
        Objects.requireNonNull(key, "key");
        int start = bucket(key);

        for (int i = 0; i < capacity; i++) {
            int idx = (start + i) % capacity;
            Entry e = table[idx];
            if (e == null) {
                return null;
            }
            if (!e.isDeleted() && key.equals(e.getKey())) {
                return e.getValue();
            }
        }
        return null;
    }

    public int getSize() {
        return size;
    }

    public int getCapacity() {
        return capacity;
    }
}
