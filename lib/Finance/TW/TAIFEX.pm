package Finance::TW::TAIFEX;
use Any::Moose;
use DateTime;
use Try::Tiny;
use File::ShareDir qw(dist_dir);
use List::MoreUtils qw(firstidx);
use Any::Moose 'X::Types::DateTime';
require MouseX::NativeTraits if Any::Moose->mouse_is_preferred;
use HTTP::Request::Common qw(POST);

use Finance::TW::TAIFEX::Product;
use Finance::TW::TAIFEX::Contract;

use 5.008_001;
our $VERSION = '0.32';

has context_date => ( is => "rw", isa => "DateTime",
                      default => sub { DateTime->now(time_zone => 'Asia/Taipei') },
                      coerce => 1);

has calendar => (is => "ro", isa => "HashRef", default => sub { {} });

has products => (
    traits => ['Hash'],
    is => "ro",
    isa => "HashRef[Finance::TW::TAIFEX::Product]",
    handles  => {
        has_product => 'exists',
        product     => 'get',
    },
    lazy_build => 1,
);


sub _build_products {
    my $self = shift;
    return {
        (map { $_ => Finance::TW::TAIFEX::Product->new_with_traits(
            traits => ['Settlement::ThirdWednesday'],
            exchange => $self,
            name => $_,
        ) } qw(TX MTX TE TF T5F MSF CPF XIF GTF
               TXO TEO TFO MSO XIO GTO)),
    };

#        (map { $_ => Finance::TW::TAIFEX::Product->new_with_traits(
#            traits => ['Settlement::ThirdToLastDayOfMonth'],
#            exchange => $self,
#            name => $_,
#        ) } qw(TGF TGO)),
#
#        (GBF => Finance::TW::TAIFEX::Product->new_with_traits(
#            traits => ['Settlement::SecondWednesday'],
#            exchange => $self,
#            name => 'GBF',
#        )),

}

=head1 NAME

Finance::TW::TAIFEX - Helper functions for Taiwan Futures Exchange

=head1 SYNOPSIS

  use Finance::TW::TAIFEX;

  my $taifex = Finance::TW::TAIFEX->new();

  $taifex->is_trading_day(); # is today a trading day?

  my $date = DateTime->now;
  $taifex->daily_futures_uri($date);
  $taifex->daily_options_uri($date);

  $taifex->contract('TX', '201001')->settlement_date;
  $taifex->product('TX')->near_term;
  $taifex->product('TX')->next_term;

=head1 DESCRIPTION

Finance::TW::TAIFEX provides useful helper functions for the Taiwan
Future Exchanges.

=head1 METHODS

=head2 product NAME

Returns the L<Finance::TW::TAIFEX::Product> object represented by NAME.

Currently supported product names:

=over

=item Futures

TX MTX TE TF T5F MSF CPF XIF GTF

=item Options

TXO TEO TFO MSO XIO GTO

=back

=head2 has_product NAME

Checks if the given product exists.

=cut

sub BUILDARGS {
    my $class = shift;
    return $#_ == 0  ? { context_date => $_[0] } : { @_ };
}

=head2 contract NAME YEAR MONTH

Returns the L<Finance::TW::TAIFEX::Contract> of the given product expires on YEAR/MONTH.

=cut

sub contract {
    my ($self, $name, $year, $month) = @_;
    unless ($month) {
        my $spec = $year;
        ($year, $month) = $spec =~ m/^(\d{4})(\d{2})$/
            or die "$spec doesn't look like a contract month";
    }

    die "unknown product $name"
        unless $self->has_product($name);

    return Finance::TW::TAIFEX::Contract->new( product => $self->product($name),
                                               year => $year,
                                               month => $month );
}

sub _read_cal {
    my ($self, $file) = @_;
    open my $fh, '<', $file or die "$file: $!" ;
    return [map { chomp; $_ } <$fh>];
}

=head2 calendar_for YEAR

Returns the trading calendar for YEAR.

=cut

sub calendar_for {
    my ($self, $year) = @_;
    $year ||= $self->context_date->year;

    return $self->calendar->{$year}
        if $self->calendar->{$year};

    my $root = try { dist_dir('Finance-TW-TAIFEX') } || 'share' ;

    $self->calendar->{$year} = $self->_read_cal("$root/calendar/$year.txt");
}

=head2 is_trading_day [DATE]

Checks if the given DATE is a known trading day.  Default DATE is the date in the current context.

=cut

sub is_trading_day {
    my ($self, $date) = @_;
    $date ||= $self->context_date;

    $self->_nth_trading_day($self->calendar_for($date->year), $date->ymd) != -1;
}

=head2 next_trading_day [DATE]

Returns the next known trading day in string after the given DATE.
This doesn't work across years yet.

=cut

sub next_trading_day {
    my ($self, $date) = @_;
    $date ||= $self->context_date;

    my $cal = $self->calendar_for($date->year);
    my $d = $date->ymd;
    my $nth = firstidx { $_ gt $d } @{$cal};
    return if $nth == $#{$cal};
    return $cal->[$nth];
}

=head2 previous_trading_day [DATE]

Returns the previous known trading day in string after the given DATE.
This doesn't work across years yet.

=cut

sub previous_trading_day {
    my ($self, $date, $offset) = @_;
    $date ||= $self->context_date;
    $offset ||= -1;

    my $cal = $self->calendar_for($date->year);
    my $nth = $self->_nth_trading_day($cal, $date->ymd);
    die "$date not a known trading day"
        if $nth < 0;

    return unless $nth + $offset >= 0;

    return $cal->[$nth + $offset];
}

sub _nth_trading_day {
    my ($self, $cal, $date) = @_;
    firstidx { $_ eq $date } @{$cal}
}

=head2 daily_futures_uri DATE

Returns the URI of the official TAIFEX futures trading records for DATE.

=cut

sub daily_futures_uri {
    my ($self, $date) = @_;
    $date ||= $self->context_date;
    return "http://www.taifex.com.tw/DailyDownload/Daily_@{[ $date->ymd('_') ]}.zip";
}

=head2 interday_futures_request($product, [$DATE])

Returns a HTTP::Request object that fetches futures monthly interday
csv file for $product of $DATE.

=cut

sub interday_futures_request {
    my ($self, $product, $date) = @_;
    $date ||= $self->context_date;
    my $from = $date->clone->truncate( to => 'month' );
    my $to = $from->clone->add( months => 1 )->subtract( days => 1 );
    return POST 'http://www.taifex.com.tw/chinese/3/3_1_2dl.asp',
      [ goday          => '',
        DATA_DATE      => $from->ymd('/'),
        DATA_DATE1     => $to->ymd('/'),
        DATA_DATE_Y    => $from->year,
        DATA_DATE_M    => $from->month,
        DATA_DATE_D    => $from->day,
        DATA_DATE_Y1   => $to->year,
        DATA_DATE_M1   => $to->month,
        DATA_DATE_D1   => $to->day,
        commodity_id2t => '',
        COMMODITY_ID   => $product ];
}

=head2 interday_options_request($product, [$DATE])

Returns a HTTP::Request object that fetches options monthly interday
csv file for $product of $DATE.

=cut

sub interday_options_request {
    my ($self, $product, $date) = @_;
    $date ||= $self->context_date;
    my $from = $date->clone->truncate( to => 'month' );
    my $to = $from->clone->add( months => 1 )->subtract( days => 1 );
    return POST 'http://www.taifex.com.tw/chinese/3/3_2_3_b.asp',
      [ goday          => '',
        DATA_DATE      => $from->ymd('/'),
        DATA_DATE1     => $to->ymd('/'),
        DATA_DATE_Y    => $from->year,
        DATA_DATE_M    => $from->month,
        DATA_DATE_D    => $from->day,
        DATA_DATE_Y1   => $to->year,
        DATA_DATE_M1   => $to->month,
        DATA_DATE_D1   => $to->day,
        COMMODITY_ID   => $product.'%' ];
}


=head2 daily_options_uri DATE

Returns the URI of the official TAIFEX options trading records for DATE.

=cut

sub daily_options_uri {
    my ($self, $date) = @_;
    $date ||= $self->context_date;
    return "http://www.taifex.com.tw/OptionsDailyDownload/OptionsDaily_@{[ $date->ymd('_') ]}.zip";
}

=head1 CAVEATS

The URI returned by C<daily_futures_uri> and C<daily_options_uri> are only valid for the last 30 trading days per the policy of TAIFEX.

=head1 AUTHOR

Chia-liang Kao E<lt>clkao@clkao.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<http://www.taifex.com.tw/>

=cut

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;

