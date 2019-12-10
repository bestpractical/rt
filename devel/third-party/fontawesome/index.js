import { library, dom } from '@fortawesome/fontawesome-svg-core'

// Import solid weight icons
import {
    faCog as fasCog,
    faEdit as fasEdit,
    faBookmark as fasBookmark,
    faProjectDiagram as fasProjectDiagram,
    faEnvelopeOpenText as fasEnvelopeOpenText,
    faReply as fasReply,
    faComment as fasComment,
    faForward as fasForward,
    faLink as fasLink,
} from '@fortawesome/free-solid-svg-icons'


// Import regular weight icons
import {
    faEdit as farEdit,
    faBookmark as farBookmark,
    faClock as farClock,
    faCalendarAlt as farCalendarAlt,
    faPlayCircle as farPlayCircle,
    faPauseCircle as farPauseCircle,
    faArrowAltCircleUp as farArrowAltCircleUp,
    faTimesCircle as farTimesCircle,
    faQuestionCircle as farQuestionCircle,
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
    fasEnvelopeOpenText,
    fasReply,
    fasComment,
    fasForward,
    fasLink,
    // Regular
    farEdit,
    farBookmark,
    farClock,
    farCalendarAlt,
    farPlayCircle,
    farPauseCircle,
    farArrowAltCircleUp,
    farTimesCircle,
    farQuestionCircle,
    // Brands
//    fabLinux
)

// Replace any existing <i> tags with <svg> and set up a MutationObserver to
// continue doing this as the DOM changes.
dom.watch()
