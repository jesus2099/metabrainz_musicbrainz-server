// This file is part of MusicBrainz, the open internet music database.
// Copyright (C) 2015—2016 MetaBrainz Foundation
// Licensed under the GPL version 2, or (at your option) any later version:
// http://www.gnu.org/licenses/gpl-2.0.txt

function _commaOnlyList(l, items) {
  if (!items.length) {
    return '';
  }

  let output = l('{last_list_item}', {
    last_list_item: items.pop(),
  });

  items.reverse();

  for (let i = 0; i < items.length; i++) {
    output = l('{commas_only_list_item}, {rest}', {
      commas_only_list_item: items[i],
      rest: output,
    });
  }

  return output;
}

const commaOnlyList = (items) => _commaOnlyList(exp.l, items);
const commaOnlyListText = (items) => _commaOnlyList(texp.l, items);

export default commaOnlyList;

export {commaOnlyListText};
