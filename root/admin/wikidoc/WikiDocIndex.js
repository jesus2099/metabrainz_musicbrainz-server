/*
 * @flow strict-local
 * Copyright (C) 2020 MetaBrainz Foundation
 *
 * This file is part of MusicBrainz, the open internet music database,
 * and is licensed under the GPL version 2, or (at your option) any
 * later version: http://www.gnu.org/licenses/gpl-2.0.txt
 */

import * as React from 'react';

import Layout from '../../layout';
import Table from '../../components/Table';
import bracketed from '../../static/scripts/common/utility/bracketed';

import type {WikiDocT} from './types';

type PropsT = {
  +$c: CatalystContextT,
  +pages: $ReadOnlyArray<WikiDocT>,
  +updatesRequired: boolean,
  +wikiIsUnreachable: boolean,
  +wikiServer: string,
};

const WikiDocTable = ({
  $c,
  pages,
  updatesRequired,
  wikiServer,
}: PropsT) => {
  const columns = React.useMemo(
    () => {
      const nameColumn = {
        Cell: ({cell: {value}}) => (
          <a href={'/doc/' + encodeURIComponent(value)}>{value}</a>
        ),
        Header: N_l('Page name'),
        accessor: 'id',
        cellProps: {className: 'title'},
        id: 'name',
      };
      const transcludedVersionColumn = {
        Header: N_l('Transcluded version'),
        accessor: 'version',
        cellProps: {
          className: 'c transcluded-version',
          style: (updatesRequired && $c.user?.is_wiki_transcluder)
            ? {textAlign: 'right'}
            : null,
        },
        headerProps: {className: 'c'},
        id: 'transcluded-version',
      };
      const wikiVersionColumn = {
        Cell: ({row: {original}}) => (
          <>
            {original.wiki_version === original.version ? null : (
              <>
                <span
                  className="wiki-version"
                  style={{color: 'red'}}
                >
                  {original.wiki_version === 0
                    ? l('Error!')
                    : original.wiki_version}
                </span>
                {original.wiki_version ? (
                  <>
                    {' '}
                    {bracketed(
                      <a
                        href={'//' + wikiServer +
                              '/' + encodeURIComponent(original.id) +
                              '?diff=' + original.wiki_version +
                              '&oldid=' + original.version}
                      >
                        {l('diff')}
                      </a>,
                    )}
                  </>
                ) : null}
              </>
            )}
          </>
        ),
        Header: N_l('Wiki version'),
        accessor: 'wiki_version',
        headerProps: {className: 'c'},
        id: 'wiki-version',
      };
      const actionsColumn = {
        Cell: ({row: {original}}) => (
          <>
            <a href={'/admin/wikidoc/edit' +
                     '?page=' + encodeURIComponent(original.id) +
                     '&new_version=' + original.wiki_version}
            >
              {l('Update')}
            </a>
            {' | '}
            <a href={'/admin/wikidoc/delete' +
                     '?page=' + encodeURIComponent(original.id)}
            >
              {l('Remove')}
            </a>
            {' | '}
            <a href={'//' + wikiServer +
                     '/' + encodeURIComponent(original.id)}
            >
              {l('View on wiki')}
            </a>
          </>
        ),
        Header: l('Actions'),
        accessor: 'id',
        cellProps: {className: 'actions c'},
        headerProps: {className: 'c'},
        id: 'actions',
      };

      return [
        nameColumn,
        transcludedVersionColumn,
        wikiVersionColumn,
        ...($c.user?.is_wiki_transcluder ? [actionsColumn] : []),
      ];
    },
    [
      $c.user,
      updatesRequired,
      wikiServer,
    ],
  );

  return (
    <Table
      className="wiki-pages"
      columns={columns}
      data={pages}
    />
  );
};

const WikiDocIndex = (props: PropsT): React.Element<typeof Layout> => (
  <Layout $c={props.$c} fullWidth title={l('Transclusion Table')}>
    <div className="content">
      <h1>{l('Transclusion Table')}</h1>
      <p>
        {exp.l(
          `Read the {doc|WikiDocs} documentation for an overview of how
           transclusion works.`,
          {doc: '/doc/WikiDocs'},
        )}
      </p>
      {props.$c.user?.is_wiki_transcluder ? (
        <>
          <ul>
            <li key="create">
              <a href="/admin/wikidoc/create">
                {l('Add a new entry')}
              </a>
            </li>
            <li key="history">
              <a href="/admin/wikidoc/history">
                {l('View transclusion history')}
              </a>
            </li>
          </ul>
          <p>
            {exp.l(`<strong>Note:</strong> MediaWiki does not check to
                    see if the version number matches the page name,
                    it will take the version number and provide
                    whatever page is associated with it. Make sure to
                    double check your work when updating a page!`)}
          </p>
        </>
      ) : null}

      {props.wikiIsUnreachable ? (
        <p style={{color: 'red', fontWeight: 'bold'}}>
          {l('There was a problem accessing the wiki API.')}
        </p>
      ) : null}
    </div>

    <WikiDocTable {...props} />
  </Layout>
);

export default WikiDocIndex;
