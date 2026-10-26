this.find = function(){
    this.activity.loader(false);
    
    // 1. Берем ID фильма (Кинопоиск или IMDB), который Лампа уже знает
    let kp_id = object.movie.kinopoisk_id || '';
    let movie_title = object.movie.title || object.search;
    
    if(!kp_id) {
        this.empty('У этого фильма в Лампе нет ID Кинопоиска. Попробуйте найти другой фильм для проверки.');
        return;
    }

    // 2. Формируем прямую ссылку на плеер вашего сайта по его правилам (через ID Кинопоиска)
    // {SECRET_SITE} автоматически превратится в https://troutcdn.site
    let player_url = '{SECRET_SITE}/?kp=' + kp_id;

    // 3. Создаем красивую кнопку фильма для меню Лампы
    let item = Lampa.Template.get('online', {
        title: 'Смотреть: ' + movie_title,
        quality: 'Авто',
        info: ''
    });

    // 4. При клике на кнопку открываем ваш сайт во встроенном плеере или Web-видео
    item.on('hover:enter', () => {
        Lampa.Player.play({
            url: player_url,
            title: movie_title,
            is_opened_window: true // Откроет плеер вашего сайта на весь экран
        });
        Lampa.Player.callback(() => {
            Lampa.Controller.toggle('content');
        });
    }).on('hover:focus', (e) => {
        scroll.update($(e.target), true);
    });

    scroll.clear();
    scroll.append(item);
    this.loading(false);
    this.start(true);
}
