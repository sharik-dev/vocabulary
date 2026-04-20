//
//  dailyVocabularyLiveActivity.swift
//  dailyVocabulary
//
//  Created by Sharik Mohamed on 20/04/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct dailyVocabularyAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct dailyVocabularyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: dailyVocabularyAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension dailyVocabularyAttributes {
    fileprivate static var preview: dailyVocabularyAttributes {
        dailyVocabularyAttributes(name: "World")
    }
}

extension dailyVocabularyAttributes.ContentState {
    fileprivate static var smiley: dailyVocabularyAttributes.ContentState {
        dailyVocabularyAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: dailyVocabularyAttributes.ContentState {
         dailyVocabularyAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: dailyVocabularyAttributes.preview) {
   dailyVocabularyLiveActivity()
} contentStates: {
    dailyVocabularyAttributes.ContentState.smiley
    dailyVocabularyAttributes.ContentState.starEyes
}
