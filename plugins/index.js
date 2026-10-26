(function () {
    'use strict';

    // 1. ИНИЦИАЛИЗАЦИЯ И ПЕРЕВОД ИНТЕРФЕЙСА
    if(!Lampa.Lang){
        let lang_data = {};
        Lampa.Lang = {
            add: (data)=>{ lang_data = data; },
            translate: (key)=>{ return lang_data[key] ? lang_data[key].ru : key; }
        };
    }

    Lampa.Lang.add({
        title_online: { ru: 'Личный Онлайн' },
        online_query_start: { ru: 'По запросу' },
        online_query_end: { ru: 'нет результатов' }
    });

    function resetTemplates(){
        Lampa.Template.add('online_item',`<div class="online selector">
            <div class="online__body">
                <div style="position: absolute;left: 0;top: -0.3em;width: 2.4em;height: 2.4em">
                    <svg style="height: 2.4em; width:  2.4em;" viewBox="0 0 128 128" fill="none" xmlns="http://w3.org">
                        <circle cx="64" cy="64" r="56" stroke="white" stroke-width="16"/>
                        <path d="M90.5 64.3827L50 87.7654L50 41L90.5 64.3827Z" fill="white"/>
                    </svg>
                </div>
                <div class="online__title" style="padding-left: 2.1em;">{title}</div>
                <div class="online__quality" style="padding-left: 3.4em;">{quality}</div>
            </div>
        </div>`);
    }

    const button = `<div class="full-start__button selector view--online" data-subtitle="v2.0-stable">
        <svg xmlns="http://w3.org" viewBox="0 0 30.051 30.051" fill="currentColor" width="512" height="512">
            <path d="M19.982,14.438l-6.24-4.536c-0.229-0.166-0.533-0.191-0.784-0.062c-0.253,0.128-0.411,0.388-0.411,0.669v9.069 c0,0.284,0.158,0.543,0.411,0.671c0.107,0.054,0.224,0.081,0.342,0.081c0.154,0,0.31-0.049,0.442-0.146l6.24-4.532 c0.197-0.145,0.312-0.369,0.312-0.607C20.295,14.803,20.177,14.58,19.982,14.438z"/>
            <path d="M15.026,0.002C6.726,0.002,0,6.728,0,15.028c0,8.297,6.726,15.021,15.026,15.021c8.298,0,15.025-6.725,15.025-15.021 C30.052,6.728,23.324,0.002,15.026,0.002z M15.026,27.542c-6.912,0-12.516-5.601-12.516-12.514c0-6.91,5.604-12.518,12.516-12.518 c6.911,0,12.514,5.607,12.514,12.518C27.541,21.941,21.937,27.542,15.026,27.542z"/>
        </svg>
        <span>#{title_online}</span>
    </div>`;

    // 2. ДВИЖОК ПОИСКА ПО ВЕЧНОЙ БАЗЕ VIDEOCDN
    function VideoCDNComponent(object) {
        let network = new Lampa.Reguest();
        let scroll = new Lampa.Scroll({mask:true,over: true});
        let files = new Lampa.Files(object);
        
        scroll.body().addClass('torrent-list');

        this.create = function(){
            this.activity.loader(true);
            files.append(scroll.render());
            this.search();
            return this.render();
        };

        this.search = function(){
            scroll.clear();
            this.find();
        };

        this.find = function(){
            let kp_id = object.movie.kinopoisk_id || '';
            let movie_title = object.movie.title || object.search;
            
            // Если у фильма нет ID Кинопоиска, пробуем искать по текстовому названию
            let search_param = kp_id ? 'kp_id=' + kp_id : 'title=' + encodeURIComponent(movie_title);

            // Официальное стабильное API, которое проксируется через ваш Koyeb
            let api_url = 'https://svetacdn.in&' + search_param;

            network.clear();
            network.timeout(1000 * 12);
            
            network.native(api_url, (json) => {
                this.activity.loader(false);
                let response = typeof json === 'string' ? JSON.parse(json) : json;

                if(response && response.data && response.data.length > 0){
                    let movie_data = response.data[0];
                    let iframe_url = movie_data.iframe_src; // Ссылка на готовый плеер балансера

                    if(!iframe_url.match(/^http/)) {
                        iframe_url = 'https:' + iframe_url;
                    }

                    // Создаем красивую кнопку переключения на плеер
                    let item = Lampa.Template.get('online_item', {
                        title: 'Включить плеер: ' + movie_title,
                        quality: movie_data.quality || '1080p'
                    });

                    item.on('hover:enter', () => {
                        // Запускаем видео на весь экран во встроенном веб-окне Лампы
                        Lampa.Player.play({
                            url: iframe_url,
                            title: movie_title,
                            is_opened_window: true 
                        });
                        Lampa.Player.callback(() => { Lampa.Controller.toggle('content'); });
                    }).on('hover:focus', (e) => {
                        scroll.update($(e.target), true);
                    });

                    scroll.append(item);
                    this.activity.toggle();
                    this.start();
                } else {
                    this.emptyForQuery(movie_title);
                }
            }, (a, c) => {
                this.empty('Ошибка сети вашего прокси. Проверьте статус Koyeb. ' + network.errorDecode(a, c));
            });
        };

        this.empty = function(msg){
            let empty = Lampa.Template.get('list_empty');
            if(msg) empty.find('.empty__descr').text(msg);
            scroll.append(empty);
            this.activity.loader(false);
            this.activity.toggle();
        };

        this.emptyForQuery = function(query){
            this.empty(Lampa.Lang.translate('online_query_start') + ' (' + query + ') ' + Lampa.Lang.translate('online_query_end'));
        };

        this.start = function(){
            if(Lampa.Activity.active().activity !== this.activity) return;
            let first_card = scroll.render().find('.selector').eq(0);
            Lampa.Background.immediately(Lampa.Utils.cardImgBackground(object.movie));

            Lampa.Controller.add('content',{
                toggle: ()=>{
                    Lampa.Controller.collectionSet(scroll.render(), files.render());
                    Lampa.Controller.collectionFocus(first_card || false, scroll.render());
                },
                up: ()=>{ if(!Navigator.move('up')) Lampa.Controller.toggle('head'); },
                down: ()=>{ Navigator.move('down'); },
                right: ()=>{ Navigator.move('right'); },
                left: ()=>{ if(!Navigator.move('left')) Lampa.Controller.toggle('menu'); },
                back: ()=>{ Lampa.Activity.backward(); }
            });
            Lampa.Controller.toggle('content');
        };

        this.render = function(){ return files.render(); };
        this.destroy = function(){ network.clear(); files.destroy(); scroll.destroy(); network = null; };
    }

    // РЕГИСТРАЦИЯ ПЛАГИНА В СИСТЕМЕ
    Lampa.Component.add('online', VideoCDNComponent);
    resetTemplates();

    Lampa.Listener.follow('full',(e)=>{
        if(e.type == 'complite'){
            let btn = $(Lampa.Lang.translate(button));
            btn.on('hover:enter',()=>{
                resetTemplates();
                Lampa.Component.add('online', VideoCDNComponent);
                Lampa.Activity.push({
                    title: Lampa.Lang.translate('title_online'),
                    component: 'online',
                    search: e.data.movie.title,
                    movie: e.data.movie,
                    page: 1
                });
            });
            e.object.activity.render().find('.view--torrent').after(btn);
        }
    });
})();
