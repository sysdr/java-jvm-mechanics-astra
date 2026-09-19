public class CollisionTest {
    public static void main(String[] args) {
        System.out.println("Starting AstraKV collision verification...");

        // Classic String.hashCode() collision: both hash to 2112
        String keyA = "Aa";
        String keyB = "BB";

        if (keyA.hashCode() != keyB.hashCode()) {
            fail("Expected '" + keyA + "' and '" + keyB + "' to share hashCode");
        }

        AstraKVStore store = new AstraKVStore(8);
        int bucketA = store.bucket(keyA);
        int bucketB = store.bucket(keyB);

        System.out.println("key=" + keyA + " hashCode=" + keyA.hashCode() + " bucket=" + bucketA);
        System.out.println("key=" + keyB + " hashCode=" + keyB.hashCode() + " bucket=" + bucketB);

        if (bucketA != bucketB) {
            fail("Colliding keys must map to the same bucket");
        }

        store.put(keyA, "alpha");
        store.put(keyB, "bravo");

        String gotA = store.get(keyA);
        String gotB = store.get(keyB);

        if (!"alpha".equals(gotA) || !"bravo".equals(gotB)) {
            fail("Collision probe failed: get(Aa)=" + gotA + " get(BB)=" + gotB);
        }

        store.put(keyA, "alpha-updated");
        if (!"alpha-updated".equals(store.get(keyA)) || !"bravo".equals(store.get(keyB))) {
            fail("Overwrite of a colliding key corrupted the chain");
        }

        System.out.println("OK: colliding keys stored and retrieved independently.");
        System.out.println("Verification Complete.");
    }

    private static void fail(String message) {
        System.err.println("FAIL: " + message);
        System.exit(1);
    }
}
