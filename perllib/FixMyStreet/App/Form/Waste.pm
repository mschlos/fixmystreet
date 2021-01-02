package FixMyStreet::App::Form::Waste;

use HTML::FormHandler::Moose;
extends 'FixMyStreet::App::Form::Wizard';

has c => ( is => 'ro' );

has default_page_type => ( is => 'ro', isa => 'Str', default => 'Waste' );

has finished_action => ( is => 'ro' );

before _process_page_array => sub {
    my ($self, $pages) = @_;
    foreach my $page (@$pages) {
        $page->{type} = $self->default_page_type
            unless $page->{type};
    }
};

# Add some functions to the form to pass through to the current page
has '+current_page' => (
    handles => {
        title => 'title',
        template => 'template',
    }
);

sub wizard_finished {
    my ($form, $action) = @_;
    my $c = $form->c;
    my $success = $c->forward($action, [ $form ]);
    if (!$success) {
        $form->add_form_error('Something went wrong, please try again');
        foreach (keys %{$c->stash->{field_errors}}) {
            $form->add_form_error("$_: " . $c->stash->{field_errors}{$_});
        }
    }
    return $success;
}

# Make sure we can have pre-ticked things on the first page
before after_build => sub {
    my $self = shift;

    my $saved_data = $self->previous_form ? $self->previous_form->saved_data : $self->saved_data;

    my $c = $self->c;

    map { $saved_data->{$_} = 1 } grep { /^(service|container)-/ && $c->req->params->{$_} } keys %{$c->req->params};
};

1;
