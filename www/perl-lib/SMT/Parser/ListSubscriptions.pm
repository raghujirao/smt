package SMT::Parser::ListSubscriptions;
use strict;
use URI;
use XML::Parser;
use SMT::Utils;
use IO::Zlib;


# The handler is called with something like this
#
# $VAR1 = {
#           'SUBID'   => 'SomeID',
#           'REGCODE' => 'some regcode',
#           'NAME' => 'SuSE Linux Enterprise Server x86',
#           'SERVERCLASS' => 'ADDON',
#           'PRODUCTCLASS' => 'SLES',
#           'DURATION' => '60',
#           'STATUS' => 'ACTIVE',
#           'TYPE' => 'FULL',
#           'ENDDATE' => '1202149302',
#           'STARTDATE' => '1202149301'
#           'PRODUCTLIST' => '436,437,438,439,808',
#           'NODECOUNT' => '35'
#         };


# constructor
sub new
{
    my $pkgname = shift;
    my %opt   = @_;
    my $self  = {};

    $self->{CURRENT}   = undef;
    $self->{HANDLER}   = undef;
    $self->{ELEMENT}   = undef;
    $self->{TMP}       = "";
    $self->{LOG}       = undef;
    $self->{VBLEVEL}   = 0;
    $self->{ERRORS}    = 0;

    if(exists $opt{log} && defined $opt{log} && $opt{log})
    {
        $self->{LOG} = $opt{log};
    }
    else
    {
        $self->{LOG} = SMT::Utils::openLog();
    }

    if(exists $opt{vblevel} && defined $opt{vblevel})
    {
        $self->{VBLEVEL} = $opt{vblevel};
    }

    bless($self);
    return $self;
}

sub vblevel
{
    my $self = shift;
    if (@_) { $self->{VBLEVEL} = shift }
    return $self->{VBLEVEL};
}

# parses a xml resource
sub parse()
{
    my $self     = shift;
    my $file     = shift;
    my $handler  = shift;

    $self->{HANDLER} = $handler;

    if (!defined $file)
    {
        printLog($self->{LOG}, $self->vblevel(), LOG_ERROR, "Invalid filename");
        $self->{ERRORS} +=1;
        return $self->{ERRORS};
    }

    # for security reason strip all | characters.
    # XML::Parser ->parsefile( $file ) might be problematic
    $file =~ s/\|//g;
    if (!-e $file)
    {
        printLog($self->{LOG}, $self->vblevel(), LOG_ERROR, "File '$file' does not exist.");
        $self->{ERRORS} += 1;
        return $self->{ERRORS};
    }

    my $parser = XML::Parser->new( Handlers =>
                                   {
                                    Start=> sub { handle_start_tag($self, @_) },
                                    Char => sub { handle_char_tag($self, @_) },
                                    End=> sub { handle_end_tag($self, @_) },
                                   });

    if ( $file =~ /(.+)\.gz/ )
    {
        my $fh = IO::Zlib->new($file, "rb");
        eval {
            $parser->parse( $fh );
        };
        if ($@) {
            # ignore the errors, but print them
            chomp($@);
            printLog($self->{LOG}, $self->vblevel(), LOG_ERROR, "SMT::Parser::ListReg Invalid XML in '$file': $@");
            $self->{ERRORS} += 1;
        }
        $fh->close;
        undef $fh;
    }
    else
    {
        eval {
            $parser->parsefile( $file );
        };
        if ($@) {
            # ignore the errors, but print them
            chomp($@);
            printLog($self->{LOG}, $self->vblevel(), LOG_ERROR, "SMT::Parser::ListReg Invalid XML in '$file': $@");
            $self->{ERRORS} += 1;
        }
    }
    return $self->{ERRORS};
}

# handles XML reader start tag events
sub handle_start_tag()
{
    my $self = shift;
    my( $expat, $element, %attrs ) = @_;

    if(lc($element) eq "subscription")
    {
        $self->{ELEMENT} = uc($element);
        $self->{TMP} = "";
    }
}


sub handle_char_tag
{
    my $self = shift;
    my( $expat, $string) = @_;

    chomp($string);
    return if($string =~ /^\s*$/);

    $self->{TMP} .= $string;
}

sub handle_end_tag
{
    my( $self, $expat, $element ) = @_;

    if($element && lc($element) eq "subscription")
    {
        # first call the callback
        $self->{HANDLER}->($self->{CURRENT});

        $self->{ELEMENT} = undef;
        $self->{CURRENT} = undef;
        $self->{TMP} = "";
    }
    elsif($self->{ELEMENT} eq "SUBSCRIPTION")
    {
        chomp($self->{TMP});

        if(lc($element) eq "type")
        {
            $self->{CURRENT}->{TYPE} = $self->{TMP};
        }
        elsif(lc($element) eq "substatus")
        {
            $self->{CURRENT}->{STATUS} = $self->{TMP};
        }
        elsif(lc($element) eq "start-date")
        {
            $self->{CURRENT}->{STARTDATE} = $self->{TMP};
        }
        elsif(lc($element) eq "end-date")
        {
            $self->{CURRENT}->{ENDDATE} = $self->{TMP};
        }
        elsif(lc($element) eq "duration")
        {
            $self->{CURRENT}->{DURATION} = $self->{TMP};
        }
        elsif(lc($element) eq "server-class")
        {
            $self->{CURRENT}->{SERVERCLASS} = $self->{TMP};
        }
        elsif(lc($element) eq "product-class")
        {
            $self->{CURRENT}->{PRODUCTCLASS} = $self->{TMP};
        }
        elsif(lc($element) eq "regcode")
        {
            $self->{CURRENT}->{REGCODE} = $self->{TMP};
        }
        elsif(lc($element) eq "subid")
        {
            $self->{CURRENT}->{SUBID} = $self->{TMP};
        }
        elsif(lc($element) eq "subname")
        {
            $self->{CURRENT}->{NAME} = $self->{TMP};
        }
        elsif(lc($element) eq "productlist")
        {
            $self->{CURRENT}->{PRODUCTLIST} = $self->{TMP};
        }
        elsif(lc($element) eq "nodecount")
        {
            $self->{CURRENT}->{NODECOUNT} = $self->{TMP};
        }
        elsif(lc($element) eq "consumed")
        {
            $self->{CURRENT}->{CONSUMED} = $self->{TMP};
        }
        elsif(lc($element) eq "consumed-virtual")
        {
            $self->{CURRENT}->{CONSUMEDVIRT} = $self->{TMP};
        }

        $self->{TMP} = "";
    }
}

1;
