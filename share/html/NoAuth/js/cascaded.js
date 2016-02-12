%# BEGIN BPS TAGGED BLOCK {{{
%#
%# COPYRIGHT:
%#
%# This software is Copyright (c) 1996-2016 Best Practical Solutions, LLC
%#                                          <sales@bestpractical.com>
%#
%# (Except where explicitly superseded by other copyright notices)
%#
%#
%# LICENSE:
%#
%# This work is made available to you under the terms of Version 2 of
%# the GNU General Public License. A copy of that license should have
%# been provided with this software, but in any event can be snarfed
%# from www.gnu.org.
%#
%# This work is distributed in the hope that it will be useful, but
%# WITHOUT ANY WARRANTY; without even the implied warranty of
%# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%# General Public License for more details.
%#
%# You should have received a copy of the GNU General Public License
%# along with this program; if not, write to the Free Software
%# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
%# 02110-1301 or visit their web page on the internet at
%# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
%#
%#
%# CONTRIBUTION SUBMISSION POLICY:
%#
%# (The following paragraph is not intended to limit the rights granted
%# to you to modify and distribute this software under the terms of
%# the GNU General Public License and is only of importance to you if
%# you choose to contribute your changes and enhancements to the
%# community by submitting them to Best Practical Solutions, LLC.)
%#
%# By intentionally submitting any modifications, corrections or
%# derivatives to this work, or any other work intended for use with
%# Request Tracker, to Best Practical Solutions, LLC, you confirm that
%# you are the copyright holder for those contributions and you grant
%# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
%# royalty-free, perpetual, license to use, copy, create derivative
%# works based on those contributions, and sublicense and distribute
%# those contributions and any derivatives thereof.
%#
%# END BPS TAGGED BLOCK }}}
function filter_cascade (id, vals) {
    var element = document.getElementById(id);
    if (!element) { return };

    if ( element.tagName == 'SELECT' ) {
        return filter_cascade_select.apply(this, arguments);
    }
    else {
        if ( !( vals instanceof Array ) ) {
            vals = [vals];
        }

        if ( arguments.length == 3 && (vals.length == 0 || (vals.length == 1 && vals[0] == '')) ) {
            // no category, and the category is from a hierchical cf;
            // leave it empty
            jQuery(element).find('div').hide();
        }
        else {
            jQuery(element).find('div').hide().find('input').attr('disabled', 'disabled');
            jQuery(element).find('div[data-name=]').show().find('input').attr('disabled', '');
            jQuery(element).find('div.none').show().find('input').attr('disabled','');
            for ( var j = 0; j < vals.length; j++ ) {
                jQuery(element).find('div[data-name^=' + vals[j] + ']').show().find('input').attr('disabled', '');
            }
        }
    }
}

function filter_cascade_select (id, vals) {
    var select = document.getElementById(id);
    var complete_select = document.getElementById(id + "-Complete" );
    if ( !( vals instanceof Array ) ) {
        vals = [vals];
    }

    if (!select) { return };
    var i;
    var children = select.childNodes;

    if ( complete_select ) {
        jQuery(select).children().remove();

        var complete_children = complete_select.childNodes;

        var cloned_labels = {};
        var cloned_empty_label;
        for ( var j = 0; j < vals.length; j++ ) {
            var val = vals[j];
            if ( val == '' && arguments.length == 3 ) {
                // no category, and the category is from a hierchical cf;
                // leave this set of options empty
            } else if ( val == '' ) {
                // no category, let's clone all node
                jQuery(select).append(jQuery(complete_children).clone());
                break;
            }
            else {
                var labels_to_clone = {};
                for (i = 0; i < complete_children.length; i++) {
                    if (!complete_children[i].label ||
                          (complete_children[i].hasAttribute &&
                                !complete_children[i].hasAttribute('label') ) ) {
                        if ( cloned_empty_label ) {
                            continue;
                        }
                    }
                    else if ( complete_children[i].label.substr(0, val.length) == val ) {
                        if ( cloned_labels[complete_children[i].label] ) {
                            continue;
                        }
                        labels_to_clone[complete_children[i].label] = true;
                    }
                    else {
                        continue;
                    }

                    jQuery(select).append(jQuery(complete_children[i]).clone());
                }

                if ( !cloned_empty_label )
                    cloned_empty_label = true;

                for ( label in labels_to_clone ) {
                    if ( !cloned_labels[label] )
                        cloned_labels[label] = true;
                }
            }
        }
    }
    else {
// for back compatibility
        for (i = 0; i < children.length; i++) {
            if (!children[i].label) { continue };
            if ( val == '' && arguments.length == 3 ) {
                hide(children[i]);
                continue;
            }
            if ( val == '' || children[i].label.substr(0, val.length) == val) {
                show(children[i]);
                continue;
            }
            hide(children[i]);
        }
    }
}
