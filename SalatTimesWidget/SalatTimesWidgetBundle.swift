import WidgetKit
import SwiftUI

@main
struct SalatTimesWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Two kinds rather than one with two looks: the gallery lists each separately, so
        // the choice between "what's next" and "the whole day" is made when adding it.
        NextPrayerWidget()
        TodayWidget()
    }
}
