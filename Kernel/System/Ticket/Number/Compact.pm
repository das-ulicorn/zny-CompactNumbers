# --
# Copyright (C) 2025 Ulrich M. Schwarz
#
# adapted from Kernel/System/Ticket/Numer/Date.pm,
# of which:
# Copyright (C) 2021 Znuny GmbH, https://znuny.org/
# Copyright (C) 2001-2021 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (GPL). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

# Generates Ticketnumbers like
# (YY)(j)(ss...),
# j is daynumber-of-year, and all components
# are converted to a higher base.

package Kernel::System::Ticket::Number::Compact;

use strict;
use warning;

use Math::Base::Convert;

use parent qw(Kernel::System::Ticket::NumberBase);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DateTime',
);

my @READABLE_LEXITS = split(//, "0123456789cfhjkmprtwxy");
my $d2sht = new Math::Base::Convert('10', \@READABLE_LEXITS);
my $sht2d = new Math::Base::Convert(\@READABLE_LEXITS, '10');
# remove vowels to reduce chance of things that look like words.
# remove i o l z s, confusable with 1 0 1 2 5
# only have one out of bdpq (and b-6, q-9)
# only have one out of mn, one out of uvw
# 0 should be first for padding reasons, the rest could be jumbled,
# because technically, you should sort by ticketid, not by ticketnumber.
   

sub IsDateBased {
    return 1;
}

sub TicketNumberBuild {
    my ( $Self, $Offset ) = @_;

    $Offset ||= 0;

    my $Counter = $Self->TicketNumberCounterAdd(
        Offset => 1 + $Offset,
    );

    return if !$Counter;

    # convert $counter into something shorter.
    $Counter = $d2sht->cnv($Counter);
    
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $SystemID = $ConfigObject->Get('SystemID');

    if ( $ConfigObject->Get('Ticket::NumberGenerator::Date::UseFormattedCounter') ) {
        my $MinSize = $ConfigObject->Get('Ticket::NumberGenerator::MinCounterSize')
            || 5;

        # Pad ticket number with leading '0' to length $MinSize (config option).
        $Counter = sprintf "%0.*s", $MinSize, $Counter;
    }

    my $DateTimeObject = $Kernel::OM->Create(
        'Kernel::System::DateTime'
    );
    my $DateTimeSettings = $DateTimeObject->Get();

    # Create new ticket number.
    my $TicketNumber =
	$d2sht->cnv( $DateTimeSettings->Format(Format=>'%y%j') )
        . $SystemID . $Counter;

    return $TicketNumber;
}

sub GetTNByString {
    my ( $Self, $String ) = @_;

    if ( !$String ) {
        return;
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my $CheckSystemID = $ConfigObject->Get('Ticket::NumberGenerator::CheckSystemID');
    my $SystemID      = '';

    if ($CheckSystemID) {
        $SystemID = $ConfigObject->Get('SystemID');
    }

    my $TicketHook        = $ConfigObject->Get('Ticket::Hook');
    my $TicketHookDivider = $ConfigObject->Get('Ticket::HookDivider');

    # Check ticket number.
    if ( $String =~ /\Q$TicketHook$TicketHookDivider\E(\w{4}$SystemID\w{1,40})/i ) {
        return $1;
    }

    if ( $String =~ /\Q$TicketHook\E:\s{0,2}(\w{4}$SystemID\w{1,40})/i ) {
        return $1;
    }

    return;
}


1;
