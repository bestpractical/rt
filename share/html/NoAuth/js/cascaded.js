%# BEGIN BPS TAGGED BLOCK {{{
%#
%# COPYRIGHT:
%#
%# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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
function filter_cascade (id, val) {
    var select = document.getElementById(id);
    var complete_select = document.getElementById(id + "-Complete" );

    if (!select) { return };
    var i;
    var children = select.childNodes;

    if ( complete_select ) {
        while (select.hasChildNodes()){
            select.removeChild(select.firstChild);
        }

        var complete_children = complete_select.childNodes;

        if ( val == '' && arguments.length == 3 ) {
            // no category, and the category is from a hierchical cf;
            // leave this set of options empty
        } else if ( val == '' ) {
            // no category, let's clone all node
            for (i in complete_children) {
                if ( complete_children[i].cloneNode ) {
                    new_option = complete_children[i].cloneNode(true);
                    select.appendChild(new_option);
                }
            }
        }
        else {
            for (i in complete_children) {
                if (!complete_children[i].label ||
                        complete_children[i].label.substr(0, val.length) == val ) {
                    if ( complete_children[i].cloneNode ) {
                        new_option = complete_children[i].cloneNode(true);
                        select.appendChild(new_option);
                    }
                }
            }
        }
    }
    else {
// for back compatibility
        for (i in children) {
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
