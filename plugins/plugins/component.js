    this.find = function(){
        // Проверяем, есть ли у фильма ID Кинопоиска
        let kp_id = object.movie.kinopoisk_id || (object.movie.id_db ? object.movie.id_db : '');
        
        if(!kp_id) {
            this.empty('У этого фильма нет ID Кинопоиска в базе Lampa. Поиск невозможен.');
            return;
        }

        // {SECRET_SITE} автоматически превратится в https://fzv-0piz2h6.troutcdn.site
        // Формируем правильный запрос к вашему плееру по ID Кинопоиска
        let url = '{SECRET_SITE}/' + kp_id;
        
        network.clear();
        network.timeout(1000 * 15);
        
        // Отправляем скрытый запрос через ваш сервер Koyeb
        network.native(url, (response) => {
            // Так как сайт возвращает готовый плеер, мы создаем элемент для Lampa
            this.activity.loader(false);
            
            let file_title = object.movie.title || object.search;
            
            // Создаем кнопку фильма для встроенного плеера
            let item = Lampa.Template.get('online', {
                title: file_title,
                quality: '1080p / Torrent',
                info: ''
            });

            item.on('hover:enter', () => {
                // Передаем ссылку на ваш секретный адаптивный плеер в Lampa
                Lampa.Player.play({
                    url: url, 
                    title: file_title
                });
                Lampa.Player.callback(() => {
                    Lampa.Controller.toggle('content');
                });
            }).on('hover:focus', (e) => {
                scroll.update($(e.target), true);
            });

            scroll.append(item);
            this.loading(false);
            this.start(true);
        }, (a, c) => {
            // Если фильм совсем новый и его еще нет на сайте, покажем ошибку
            this.empty('Фильм еще не загружен на ваш плеер: ' + network.errorDecode(a, c));
        });
    }
