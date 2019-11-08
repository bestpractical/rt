import { library, dom } from '@fortawesome/fontawesome-svg-core'

// Import solid weight icons
import {
    faCog as fasCog,
    faEdit as fasEdit,
    faBookmark as fasBookmark,
    faProjectDiagram as fasProjectDiagram,
} from '@fortawesome/free-solid-svg-icons'


// Import regular weight icons
import {
    faEdit as farEdit,
    faBookmark as farBookmark,
    faClock as farClock,
    faCalendarAlt as farCalendarAlt
} from '@fortawesome/free-regular-svg-icons'

/*
// Import brand icons
import {
    faLinux as fabLinux
} from '@fortawesome/free-brands-svg-icons';
*/

// Add icons to library
library.add(
    // Solid
    fasCog,
    fasEdit,
    fasBookmark,
    fasProjectDiagram,
    // Regular
    farEdit,
    farBookmark,
    farClock,
    farCalendarAlt
    // Brands
//    fabLinux
)

// Replace any existing <i> tags with <svg> and set up a MutationObserver to
// continue doing this as the DOM changes.
dom.watch()
