                        if subMenuItem.keyEquivalent.lowercased() == keyEquivalent {
                            if subMenuItem.isEnabled, let action = subMenuItem.action {
                                NSApp.sendAction(action, to: subMenuItem.target, from: self)
                                return true
                            }
                        }
