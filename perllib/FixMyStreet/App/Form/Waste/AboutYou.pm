package FixMyStreet::App::Form::Waste::AboutYou;

use utf8;
use HTML::FormHandler::Moose::Role;
use FixMyStreet::SMS;

has_field name => (
    type => 'Text',
    label => 'Your name',
    required => 1,
    validate_method => sub {
        my $self = shift;
        $self->add_error('Please enter your full name.')
            if length($self->value) < 5
                || $self->value !~ m/\s/
                || $self->value =~ m/\ba\s*n+on+((y|o)mo?u?s)?(ly)?\b/i;
    },
);

has_field phone => (
    type => 'Text',
    label => 'Telephone number',
    validate_method => sub {
        my $self = shift;
        my $parsed = FixMyStreet::SMS->parse_username($self->value);
        $self->add_error('Please provide a valid phone number')
            unless $parsed->{phone};
    }
);

has_field email => (
    type => 'Email',
    tags => {
        hint => 'If you provide an email address, we can send you order status updates'
    },
);

1;
