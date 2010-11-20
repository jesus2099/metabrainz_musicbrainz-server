package MusicBrainz::Server::Data::Recording;

use Moose;
use MusicBrainz::Server::Entity::Recording;
use MusicBrainz::Server::Data::Track;
use MusicBrainz::Server::Data::Utils qw(
    defined_hash
    generate_gid
    placeholders
    load_subobjects
    query_to_list_limited
);

extends 'MusicBrainz::Server::Data::CoreEntity';
with 'MusicBrainz::Server::Data::Role::Annotation' => { type => 'recording' };
with 'MusicBrainz::Server::Data::Role::Editable' => { table => 'recording' };
with 'MusicBrainz::Server::Data::Role::Rating' => { type => 'recording' };
with 'MusicBrainz::Server::Data::Role::Tag' => { type => 'recording' };
with 'MusicBrainz::Server::Data::Role::LinksToEdit' => { table => 'recording' };
with 'MusicBrainz::Server::Data::Role::BrowseVA';

sub _table
{
    return 'recording JOIN track_name name ON recording.name=name.id';
}

sub _columns
{
    return 'recording.id, recording.gid, name.name,
            recording.artist_credit AS artist_credit_id,
            recording.length, recording.comment,
            recording.edits_pending, recording.last_updated';
}
sub _column_mapping
{
    return {
        id               => 'id',
        gid              => 'gid',
        name             => 'name',
        artist_credit_id => 'artist_credit_id',
        length           => 'length',
        comment          => 'comment',
        edits_pending    => 'edits_pending',
        last_updated     => 'last_updated',
    };
}

sub _id_column
{
    return 'recording.id';
}

sub _gid_redirect_table
{
    return 'recording_gid_redirect';
}

sub _entity_class
{
    return 'MusicBrainz::Server::Entity::Recording';
}

sub find_by_artist
{
    my ($self, $artist_id, $limit, $offset) = @_;

    my $query = "SELECT " . $self->_columns . "
                 FROM " . $self->_table . "
                     JOIN artist_credit_name acn
                         ON acn.artist_credit = recording.artist_credit
                 WHERE acn.artist = ?
                 ORDER BY musicbrainz_collate(name.name)
                 OFFSET ?";
    return query_to_list_limited(
        $self->c->dbh, $offset, $limit, sub { $self->_new_from_row(@_) },
        $query, $artist_id, $offset || 0);
}

sub find_by_release
{
    my ($self, $release_id, $limit, $offset) = @_;

    my $query = "SELECT " . $self->_columns . "
                 FROM " . $self->_table . "
                     JOIN track ON track.recording = recording.id
                     JOIN medium ON medium.tracklist = track.tracklist
                     JOIN release ON release.id = medium.release
                 WHERE release.id = ?
                 ORDER BY musicbrainz_collate(name.name)
                 OFFSET ?";

    return query_to_list_limited(
        $self->c->dbh, $offset, $limit, sub { $self->_new_from_row(@_) },
        $query, $release_id, $offset || 0);
}

sub load
{
    my ($self, @objs) = @_;
    return load_subobjects($self, 'recording', @objs);
}

sub insert
{
    my ($self, @recordings) = @_;
    my $sql = Sql->new($self->c->dbh);
    my $track_data = MusicBrainz::Server::Data::Track->new(c => $self->c);
    my %names = $track_data->find_or_insert_names(map { $_->{name} } @recordings);
    my $class = $self->_entity_class;
    my @created;
    for my $recording (@recordings)
    {
        my $row = $self->_hash_to_row($recording, \%names);
        $row->{gid} = $recording->{gid} || generate_gid();
        push @created, $class->new(
            id => $sql->insert_row('recording', $row, 'id'),
            gid => $row->{gid}
        );
    }
    return @recordings > 1 ? @created : $created[0];
}

sub update
{
    my ($self, $recording_id, $update) = @_;
    my $sql = Sql->new($self->c->dbh);
    my $track_data = MusicBrainz::Server::Data::Track->new(c => $self->c);
    my %names = $track_data->find_or_insert_names($update->{name});
    my $row = $self->_hash_to_row($update, \%names);
    $sql->update_row('recording', $row, { id => $recording_id });
}

sub can_delete
{
    my ($self, $recording_id) = @_;
    my $sql = Sql->new($self->c->dbh);
    my $refcount = $sql->select_single_column_array('SELECT 1 FROM track WHERE recording = ?', $recording_id);
    return @$refcount == 0;
}

sub delete
{
    my ($self, $recording) = @_;
    return unless $self->can_delete($recording->id);

    $self->c->model('Relationship')->delete_entities('recording', $recording->id);
    $self->c->model('RecordingPUID')->delete_recordings($recording->id);
    $self->c->model('ISRC')->delete_recordings($recording->id);
    $self->annotation->delete($recording->id);
    $self->tags->delete($recording->id);
    $self->rating->delete($recording->id);
    $self->remove_gid_redirects($recording->id);
    my $sql = Sql->new($self->c->dbh);
    $sql->do('DELETE FROM recording WHERE id = ?', $recording->id);
    return;
}

sub _hash_to_row
{
    my ($self, $recording, $names) = @_;
    my %row = (
        artist_credit => $recording->{artist_credit},
        length => $recording->{length},
        comment => $recording->{comment},
    );

    if ($recording->{name}) {
        $row{name} = $names->{$recording->{name}};
    }

    return { defined_hash(%row) };
}

sub load_meta
{
    my $self = shift;
    MusicBrainz::Server::Data::Utils::load_meta($self->c, "recording_meta", sub {
        my ($obj, $row) = @_;
        $obj->rating($row->{rating}) if defined $row->{rating};
        $obj->rating_count($row->{rating_count}) if defined $row->{rating_count};
    }, @_);
}

sub merge
{
    my ($self, $new_id, @old_ids) = @_;

    $self->annotation->merge($new_id, @old_ids);
    $self->tags->merge($new_id, @old_ids);
    $self->rating->merge($new_id, @old_ids);
    $self->c->model('RecordingPUID')->merge_recordings($new_id, @old_ids);
    $self->c->model('ISRC')->merge_recordings($new_id, @old_ids);
    $self->c->model('Edit')->merge_entities('recording', $new_id, @old_ids);
    $self->c->model('Relationship')->merge_entities('recording', $new_id, @old_ids);

    # Move tracks to the new recording
    my $sql = Sql->new($self->c->dbh);
    $sql->do('UPDATE track SET recording = ?
              WHERE recording IN ('.placeholders(@old_ids).')', $new_id, @old_ids);

    $self->_delete_and_redirect_gids('recording', $new_id, @old_ids);
    return 1;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2009 Lukas Lalinsky

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
