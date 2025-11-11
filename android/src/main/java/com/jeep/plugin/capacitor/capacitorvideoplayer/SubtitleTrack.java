package com.jeep.plugin.capacitor.capacitorvideoplayer;

/**
 * Represents a subtitle track configuration
 */
public class SubtitleTrack {
    private String id;
    private String url;
    private String language;
    private String label;
    private String mimeType;
    private boolean isDefault;
    private boolean isForced;

    public SubtitleTrack() {
    }

    public SubtitleTrack(String id, String url, String language) {
        this.id = id;
        this.url = url;
        this.language = language;
        this.label = language;
        this.isDefault = false;
        this.isForced = false;
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getUrl() {
        return url;
    }

    public void setUrl(String url) {
        this.url = url;
    }

    public String getLanguage() {
        return language;
    }

    public void setLanguage(String language) {
        this.language = language;
    }

    public String getLabel() {
        return label != null ? label : language;
    }

    public void setLabel(String label) {
        this.label = label;
    }

    public String getMimeType() {
        return mimeType;
    }

    public void setMimeType(String mimeType) {
        this.mimeType = mimeType;
    }

    public boolean isDefault() {
        return isDefault;
    }

    public void setDefault(boolean isDefault) {
        this.isDefault = isDefault;
    }

    public boolean isForced() {
        return isForced;
    }

    public void setForced(boolean isForced) {
        this.isForced = isForced;
    }
}

