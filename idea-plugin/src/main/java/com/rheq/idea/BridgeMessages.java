package com.rheq.idea;

import com.intellij.DynamicBundle;

final class BridgeMessages extends DynamicBundle {
    private static final BridgeMessages INSTANCE = new BridgeMessages();
    private BridgeMessages() { super("messages.BridgeBundle"); }
    static String text(String key, Object... params) { return INSTANCE.getMessage(key, params); }
}
