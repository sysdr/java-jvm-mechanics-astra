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
