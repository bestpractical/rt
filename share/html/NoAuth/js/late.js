%# BEGIN BPS TAGGED BLOCK {{{
%#
%# COPYRIGHT:
%#
%# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
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
// Lower the speed limit for hover intent event
jQuery.event.special.hover.speed = 80; // pixels per second

jQuery(function() {
    var all_inputs = jQuery("input,textarea,select");
    var parse_cf = /^Object-([\w:]+)-(\d*)-CustomField(?::\w+)?-(\d+)-(.*)$/;
    all_inputs.each(function() {
        var elem = jQuery(this);
        var parsed = parse_cf.exec(elem.attr("name"));
        if (parsed == null)
            return;
        if (/-Magic$/.test(parsed[4]))
            return;
        var name_filter_regex = new RegExp(
            "^Object-"+parsed[1]+"-"+parsed[2]+
             "-CustomField(?::\\w+)?-"+parsed[3]+"-"+parsed[4]+"$"
        );
        var update_elems = all_inputs.filter(function () {
            return name_filter_regex.test(jQuery(this).attr("name"));
        }).not(elem);
        elem.change( function() {
            var curval = elem.val();
            if ((elem.attr("type") == "checkbox") || (elem.attr("type") == "radio")) {
                curval = [ ];
                jQuery('[name="'+elem.attr("name")+'"]:checked').each( function() {
                    curval.push( jQuery(this).val() );
                });
            }
            update_elems.val(curval);
        } );
    });
});
