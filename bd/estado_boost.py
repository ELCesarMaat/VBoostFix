# Estado de Video Boost en un snapshot de Fotos (solo lectura sobre una copia de trabajo).
# Uso: python estado_boost.py <carpeta_snapshot> [patron_LIKE]   (patron por defecto: %VB-0%)
import os, shutil, sqlite3, sys, tempfile, datetime

snap = sys.argv[1]
pat = sys.argv[2] if len(sys.argv) > 2 else '%VB-0%'

# Abrir el snapshot directamente puede hacer checkpoint del -wal; se trabaja sobre una copia temporal.
work = tempfile.mkdtemp(prefix='vb_')
for f in os.listdir(snap):
    shutil.copy2(os.path.join(snap, f), work)

def ts(ms):
    if not ms:
        return '-'
    return datetime.datetime.fromtimestamp(ms / 1000).strftime('%m-%d %H:%M:%S')

def show(con, title, sql, args, fmt=None):
    cur = con.execute(sql, args)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    print(f'== {title} ({len(rows)})')
    for r in rows:
        d = dict(zip(cols, r))
        for k in (fmt or []):
            d[k] = ts(d[k])
        print('  ' + '  '.join(f'{k}={v}' for k, v in d.items()))

g = sqlite3.connect(os.path.join(work, 'gphotos0.db'))
show(g, 'local_media',
     'select _id, media_store_id, filename, blanford_format, size_bytes, owner_package_name, upload_origin,'
     ' first_backup_timestamp, is_backup_processed, has_upload_permanently_failed, is_pending'
     ' from local_media where filename like ? order by filename', (pat,), ['first_backup_timestamp'])
show(g, 'remote_media',
     'select filename, blanford_format, can_play_video, quota_charged_bytes, upload_status, upload_origin,'
     ' owner_package_name, size_bytes, width, height, server_creation_timestamp, substr(media_key,1,12) as media_key'
     ' from remote_media where filename like ? order by filename', (pat,), ['server_creation_timestamp'])
g.close()

mse = os.path.join(work, 'media_store_extras')
if os.path.exists(mse):
    m = sqlite3.connect(mse)
    g = sqlite3.connect(os.path.join(work, 'gphotos0.db'))
    ids = {r[0]: r[1] for r in g.execute('select media_store_id, filename from local_media where filename like ?', (pat,))}
    g.close()
    print(f'== media_store_extension ({len(ids)} ids de local_media)')
    for i, name in sorted(ids.items(), key=lambda x: x[1]):
        r = m.execute('select blanford_format, burst_group_type, video_width, video_height from media_store_extension where id=?', (i,)).fetchone()
        print(f'  id={i}  {name}  blanford/burst_group/w/h={r}')
    m.close()

shutil.rmtree(work, ignore_errors=True)
