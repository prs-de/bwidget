# spinbox.tcl --
#
#	BWidget SpinBox implementation.
#
# Copyright (c) 1999 by Unifix
# Copyright (c) 2000 by Scriptics Corporation.
# All rights reserved.
# 
# RCS: @(#) $Id: spinbox.tcl,v 1.8 2000/03/13 18:21:48 ericm Exp $
# -----------------------------------------------------------------------------
#  Index of commands:
#     - SpinBox::create
#     - SpinBox::configure
#     - SpinBox::cget
#     - SpinBox::setvalue
#     - SpinBox::_destroy
#     - SpinBox::_modify_value
#     - SpinBox::_test_options
# -----------------------------------------------------------------------------

namespace eval SpinBox {
    ArrowButton::use
    Entry::use

    Widget::tkinclude SpinBox frame :cmd \
	    include {-background -borderwidth -bg -bd -relief} \
	    initialize {-relief sunken -borderwidth 2}

    Widget::bwinclude SpinBox Entry .e \
        remove {-relief -bd -borderwidth -fg -bg} \
        rename {-foreground -entryfg -background -entrybg}

    Widget::declare SpinBox {
        {-range          String ""  0}
        {-values         String ""  0}
        {-modifycmd      String ""  0}
        {-repeatdelay    Int    400 0 {%d >= 0}}
        {-repeatinterval Int    100 0 {%d >= 0}}
	{-foreground     TkResource black 0 {button}}
    }

    Widget::addmap SpinBox "" :cmd {-background {}}
    Widget::addmap SpinBox ArrowButton .arrup {
        -foreground {} -background {} -disabledforeground {} -state {} \
		-repeatinterval {} -repeatdelay {}
    }
    Widget::addmap SpinBox ArrowButton .arrdn {
        -foreground {} -background {} -disabledforeground {} -state {} \
		-repeatinterval {} -repeatdelay {}
    }

    ::bind SpinBox <FocusIn> [list after idle {BWidget::refocus %W %W.e}]
    ::bind SpinBox <Destroy> {SpinBox::_destroy %W}

    interp alias {} ::SpinBox {} ::SpinBox::create
    proc use {} {}

    variable _widget
}


# -----------------------------------------------------------------------------
#  Command SpinBox::create
# -----------------------------------------------------------------------------
proc SpinBox::create { path args } {
    array set maps [list SpinBox {} :cmd {} .e {} .arrup {} .arrdn {}]
    array set maps [Widget::parseArgs SpinBox $args]
    eval frame $path $maps(:cmd) -highlightthickness 0 \
	    -takefocus 0 -class SpinBox
    Widget::initFromODB SpinBox $path $maps(SpinBox)

    set entry [eval Entry::create $path.e $maps(.e) -relief flat -bd 0]
    bindtags $path.e [linsert [bindtags $path.e] 1 SpinBoxEntry]

    set farr   [frame $path.farr -relief flat -bd 0 -highlightthickness 0]
    set height [expr {[winfo reqheight $path.e]/2-2}]
    set width  11
    set arrup  [eval ArrowButton::create $path.arrup -dir top \
	    $maps(.arrup) \
	    -highlightthickness 0 -borderwidth 1 -takefocus 0 \
	    -type button \
	    -width $width -height $height \
	    -armcommand    [list "SpinBox::_modify_value $path next arm"] \
	    -disarmcommand [list "SpinBox::_modify_value $path next disarm"]]
    set arrdn  [eval ArrowButton::create $path.arrdn -dir bottom \
	    $maps(.arrdn) \
	    -highlightthickness 0 -borderwidth 1 -takefocus 0 \
	    -type button \
	    -width $width -height $height \
	    -armcommand    [list "SpinBox::_modify_value $path previous arm"] \
	    -disarmcommand [list "SpinBox::_modify_value $path previous disarm"]]

    # --- update SpinBox value ---
    _test_options $path
    set val [Entry::cget $path.e -text]
    if { [string equal $val ""] } {
	Entry::configure $path.e -text $::SpinBox::_widget($path,curval)
    } else {
	set ::SpinBox::_widget($path,curval) $val
    }

    grid $arrup -in $farr -column 0 -row 0 -sticky nsew
    grid $arrdn -in $farr -column 0 -row 2 -sticky nsew
    grid rowconfigure $farr 0 -weight 1
    grid rowconfigure $farr 2 -weight 1

    pack $farr  -side right -fill y
    pack $entry -side left  -fill both -expand yes

    ::bind $entry <Key-Up>    "SpinBox::_modify_value $path next activate"
    ::bind $entry <Key-Down>  "SpinBox::_modify_value $path previous activate"
    ::bind $entry <Key-Prior> "SpinBox::_modify_value $path last activate"
    ::bind $entry <Key-Next>  "SpinBox::_modify_value $path first activate"

    ::bind $farr <Configure> {grid rowconfigure %W 1 -minsize [expr {%h%%2}]}

    rename $path ::$path:cmd
    proc ::$path { cmd args } "return \[eval SpinBox::\$cmd $path \$args\]"

    return $path
}

# -----------------------------------------------------------------------------
#  Command SpinBox::configure
# -----------------------------------------------------------------------------
proc SpinBox::configure { path args } {
    set res [Widget::configure $path $args]
    if { [Widget::hasChangedX $path -values] ||
         [Widget::hasChangedX $path -range] } {
        _test_options $path
    }
    return $res
}


# -----------------------------------------------------------------------------
#  Command SpinBox::cget
# -----------------------------------------------------------------------------
proc SpinBox::cget { path option } {
    return [Widget::cget $path $option]
}


# -----------------------------------------------------------------------------
#  Command SpinBox::setvalue
# -----------------------------------------------------------------------------
proc SpinBox::setvalue { path index } {
    variable _widget

    set values [Widget::getMegawidgetOption $path -values]
    set value  [Entry::cget $path.e -text]
    
    if { [llength $values] } {
        # --- -values SpinBox ---
        switch -- $index {
            next {
                if { [set idx [lsearch $values $value]] != -1 } {
                    incr idx
                } elseif { [set idx [lsearch $values "$value*"]] == -1 } {
                    set idx [lsearch $values $_widget($path,curval)]
                }
            }
            previous {
                if { [set idx [lsearch $values $value]] != -1 } {
                    incr idx -1
                } elseif { [set idx [lsearch $values "$value*"]] == -1 } {
                    set idx [lsearch $values $_widget($path,curval)]
                }
            }
            first {
                set idx 0
            }
            last {
                set idx [expr {[llength $values]-1}]
            }
            default {
                if { [string index $index 0] == "@" } {
                    set idx [string range $index 1 end]
                    if { [catch {string compare [expr {int($idx)}] $idx} res] || $res != 0 } {
                        return -code error "bad index \"$index\""
                    }
                } else {
                    return -code error "bad index \"$index\""
                }
            }
        }
        if { $idx >= 0 && $idx < [llength $values] } {
            set newval [lindex $values $idx]
        } else {
            return 0
        }
    } else {
        # --- -range SpinBox ---
	foreach {vmin vmax incr} [Widget::getMegawidgetOption $path -range] {
	    break
	}
	# Allow zero padding on the value; strip it out for calculation by
	# scanning the value into a floating point number.
	scan $value %f value
        switch -- $index {
            next {
                if { [catch {expr {double($value-$vmin)/$incr}} idx] } {
                    set newval $_widget($path,curval)
                } else {
                    set newval [expr {$vmin+(round($idx)+1)*$incr}]
                    if { $newval < $vmin } {
                        set newval $vmin
                    } elseif { $newval > $vmax } {
                        set newval $vmax
                    }
                }
            }
            previous {
                if { [catch {expr {double($value-$vmin)/$incr}} idx] } {
                    set newval $_widget($path,curval)
                } else {
                    set newval [expr {$vmin+(round($idx)-1)*$incr}]
                    if { $newval < $vmin } {
                        set newval $vmin
                    } elseif { $newval > $vmax } {
                        set newval $vmax
                    }
                }
            }
            first {
                set newval $vmin
            }
            last {
                set newval $vmax
            }
            default {
                if { [string index $index 0] == "@" } {
                    set idx [string range $index 1 end]
                    if { [catch {string compare [expr {int($idx)}] $idx} res] || $res != 0 } {
                        return -code error "bad index \"$index\""
                    }
                    set newval [expr {$vmin+int($idx)*$incr}]
                    if { $newval < $vmin || $newval > $vmax } {
                        return 0
                    }
                } else {
                    return -code error "bad index \"$index\""
                }
            }
        }
    }
    set _widget($path,curval) $newval
    Entry::configure $path.e -text $newval
    return 1
}


# -----------------------------------------------------------------------------
#  Command SpinBox::getvalue
# -----------------------------------------------------------------------------
proc SpinBox::getvalue { path } {
    variable _widget

    set values [Widget::getMegawidgetOption $path -values]
    set value  [Entry::cget $path.e -text]

    if { [llength $values] } {
        # --- -values SpinBox ---
        return  [lsearch $values $value]
    } else {
	foreach {vmin vmax incr} [Widget::getMegawidgetOption $path -range] {
	    break
	}
        if { ![catch {expr {double($value-$vmin)/$incr}} idx] &&
             $idx == int($idx) } {
            return [expr {int($idx)}]
        }
        return -1
    }
}


# -----------------------------------------------------------------------------
#  Command SpinBox::bind
# -----------------------------------------------------------------------------
proc SpinBox::bind { path args } {
    return [eval ::bind $path.e $args]
}


# -----------------------------------------------------------------------------
#  Command SpinBox::_destroy
# -----------------------------------------------------------------------------
proc SpinBox::_destroy { path } {
    variable _widget

    unset _widget($path,curval)
    Widget::destroy $path
    rename $path {}
}


# -----------------------------------------------------------------------------
#  Command SpinBox::_modify_value
# -----------------------------------------------------------------------------
proc SpinBox::_modify_value { path direction reason } {
    if { $reason == "arm" || $reason == "activate" } {
        SpinBox::setvalue $path $direction
    }
    if { ($reason == "disarm" || $reason == "activate") &&
         [set cmd [Widget::getMegawidgetOption $path -modifycmd]] != "" } {
        uplevel \#0 $cmd
    }
}

# -----------------------------------------------------------------------------
#  Command SpinBox::_test_options
# -----------------------------------------------------------------------------
proc SpinBox::_test_options { path } {
    variable _widget

    set values [Widget::getMegawidgetOption $path -values]
    if { [llength $values] } {
        set _widget($path,curval) [lindex $values 0]
    } else {
	foreach {vmin vmax incr} [Widget::getMegawidgetOption $path -range] {
	    break
	}
        if { [catch {expr {int($vmin)}}] } {
            set vmin 0
        }
        if { [catch {expr {$vmax<$vmin}} res] || $res } {
            set vmax $vmin
        }
        if { [catch {expr {$incr<0}} res] || $res } {
            set incr 1
        }
        Widget::configure $path [list -range [list $vmin $vmax $incr]]
        set _widget($path,curval) $vmin
    }
}

