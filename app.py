import os
import re
import urllib.parse
from flask import Flask, request, Response
import requests
from bs4 import BeautifulSoup

app = Flask(__name__)

# --- Вспомогательная функция проксирования M3U8 ---
def rewrite_m3u8(text, base_url, proxy_origin):
    rewritten_lines = []
    for line in text.split('\n'):
        trimmed = line.strip()
        if not trimmed:
            rewritten_lines.append(line)
            continue
        if trimmed.startswith('#'):
            fixed_line = re.sub(r'URI="([^"]+)"', lambda m: f'URI="{proxy_origin}/proxy?url={urllib.parse.quote(urllib.parse.urljoin(base_url, m.group(1)))}"', line)
            rewritten_lines.append(fixed_line)
        else:
            abs_url = urllib.parse.urljoin(base_url, trimmed)
            rewritten_lines.append(f"{proxy_origin}/proxy?url={urllib.parse.quote(abs_url)}")
    return '\n'.join(rewritten_lines)


# --- 1. Кросс-доменный МЕДИА-ПРОКСИ ---
@app.route('/proxy')
def proxy_gateway():
    target_url = request.args.get('url')
    if not target_url:
        return Response("Cherry Proxy Mode Active!", content_type="text/plain")

    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
    }
    
    try:
        upstream = requests.get(target_url, headers=headers, stream=True, timeout=15)
        
        if "mpegurl" in upstream.headers.get('Content-Type', '').lower() or target_url.lower().endswith('.m3u8'):
            proxy_origin = request.host_url.rstrip('/')
            rewritten_content = rewrite_m3u8(upstream.text, target_url, proxy_origin)
            
            resp = Response(rewritten_content, status=upstream.status_code)
            resp.headers['Content-Type'] = 'application/vnd.apple.mpegurl'
            resp.headers['Access-Control-Allow-Origin'] = '*'
            return resp

        def generate():
            for chunk in upstream.iter_content(chunk_size=4096):
                yield chunk
                
        resp = Response(generate(), status=upstream.status_code)
        resp.headers['Content-Type'] = upstream.headers.get('Content-Type', 'video/mp4')
        resp.headers['Access-Control-Allow-Origin'] = '*'
        if 'Content-Length' in upstream.headers:
            resp.headers['Content-Length'] = upstream.headers['Content-Length']
        return resp

    except Exception as e:
        return Response(f"Proxy Error: {e}", status=502)


# --- 2. ТОРРЕНТ-ПАРСЕР (Rutor XML API) ---
@app.route('/torrent')
def torrent_parser():
    search_query = request.args.get('q', '')
    if not search_query:
        return Response("<rss><channel><title>Empty</title></channel></rss>", mimetype='application/xml')

    xml_items = ""
    try:
        url = f"http://rutor.info{urllib.parse.quote(search_query)}"
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            table = soup.find('table', {'id': 'index'})
            if table:
                for row in table.find_all('tr')[1:]:
                    cols = row.find_all('td')
                    if len(cols) >= 2:
                        links = cols.find_all('a')
                        if len(links) >= 2:
                            magnet_link = links[1]['href'] # Берем вторую ссылку, там magnet
                            title = links[2].text if len(links) > 2 else links[1].text
                            
                            sp_match = re.findall(r'\d+', cols[2].text if len(cols) > 2 else "")
                            seeders = sp_match[0] if len(sp_match) > 0 else "0"
                            peers = sp_match[1] if len(sp_match) > 1 else "0"
                            
                            size_text = cols[3].text if len(cols) > 3 else "0"
                            size_bytes = 0
                            if "gb" in size_text.lower():
                                size_bytes = int(float(re.sub(r'[^\d.]', '', size_text).strip()) * 1024 * 1024 * 1024)
                            elif "mb" in size_text.lower():
                                size_bytes = int(float(re.sub(r'[^\d.]', '', size_text).strip()) * 1024 * 1024)

                            xml_items += f"""
                            <item>
                                <title>{title}</title>
                                <link>{magnet_link}</link>
                                <guid>{urllib.parse.quote(title)}</guid>
                                <size>{size_bytes}</size>
                                <torznab:attr name="seeders" value="{seeders}"/>
                                <torznab:attr name="peers" value="{peers}"/>
                            </item>
                            """
    except Exception as e:
        print(f"Torrent error: {e}")

    rss_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:torznab="http://torznab.com"><channel><title>Koyeb Free</title>{xml_items}</channel></rss>"""
    return Response(rss_xml, mimetype='application/xml')


# --- 3. JS-ПЛАГИН ДЛЯ ЛАМПЫ ---
@app.route('/plugin.js')
def get_plugin():
    host = request.host_url.rstrip('/') 
    
    js_code = f"""(function () {{
        'use strict';
        function startPlugin() {{
            Lampa.Listener.follow('full', function (e) {{
                if (e.type == 'complite') {{
                    if ($('.button--koyeb-online').length > 0) return;
                    
                    var btn = $('<div class="full-start__button selector button--koyeb-online"><span>Онлайн (Koyeb)</span></div>');
                    
                    btn.on('hover:enter', function() {{
                        var kpId = e.data.movie.kinopoisk_id;
                        if (!kpId) {{
                            Lampa.Noty.show('У этой карточки нет Kinopoisk ID');
                            return;
                        }
                        
                        Lampa.Noty.show('Ищем видеопоток...');
                        var targetApi = "https://kinobox.tv" + kpId;
                        var proxiedUrl = "{host}/proxy?url=" + encodeURIComponent(targetApi);
                        
                        Lampa.Player.play({{
                            url: proxiedUrl,
                            title: e.data.movie.title,
                            video: e.data.movie
                        }});
                    }});
                    
                    e.object.activity.render().find('.view--torrent').after(btn);
                }}
            }});
        }}
        if (window.appready) startPlugin();
        else {{ Lampa.Listener.follow('app', function (e) {{ if (e.type == 'ready') startPlugin(); }}); }}
    }})();"""
    return Response(js_code, mimetype='application/javascript')

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8000))
    app.run(host='0.0.0.0', port=port)
