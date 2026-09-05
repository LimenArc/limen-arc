import { configLeaves } from '../../config/GameConfig';
import { autoControl, el, section, sectionBody } from '../controls';

/**
 * Generic editor: walks GameConfig and renders a control for every scalar, so a
 * value is editable the moment it exists — no dedicated UI required.
 */
let filter = '';

export function buildTuningTab(root: HTMLElement): void {
  const search = el('input', 'search-box');
  search.type = 'text';
  search.placeholder = `Filter ${configLeaves().length} values…`;
  search.value = filter;
  search.addEventListener('input', () => {
    filter = search.value.trim().toLowerCase();
    renderGroups(list);
  });
  const list = el('div');
  root.append(search, list);
  renderGroups(list);
  if (filter) search.focus();
}

function renderGroups(host: HTMLElement): void {
  host.replaceChildren();
  const groups = new Map<string, string[]>();
  for (const leaf of configLeaves()) {
    if (filter && !leaf.path.toLowerCase().includes(filter)) continue;
    const group = leaf.path.split('.')[0];
    const bucket = groups.get(group) ?? [];
    bucket.push(leaf.path);
    groups.set(group, bucket);
  }
  if (groups.size === 0) {
    host.append(el('p', undefined, 'No config values match that filter.'));
    return;
  }
  for (const [group, paths] of groups) {
    const details = section(`${group} (${paths.length})`, Boolean(filter) || groups.size <= 6);
    const body = sectionBody(details);
    for (const path of paths) body.append(autoControl(path));
    host.append(details);
  }
}
