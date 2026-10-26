function component(object){
    let network  = new Lampa.Reguest()
    let scroll   = new Lampa.Scroll({mask:true,over: true})
    let files    = new Lampa.Files(object)
    let filter   = new Lampa.Filter(object)
    
    scroll.body().addClass('torrent-list')

    this.create = function(){
        this.activity.loader(true)
        files.append(scroll.render())
        this.search()
        return this.render()
    }

    this.search = function(){
        this.activity.loader(true)
        scroll.clear()
        this.find()
    }

    this.find = function(){
        // {SECRET_SITE} — это защищенная маска. Docker автоматически заменит её на ваш реальный URL
        let url = '{SECRET_SITE}/api/short?title=' + encodeURIComponent(object.search);
        
        network.clear()
        network.timeout(1000 * 15)
        
        network.native(url, (json) => {
            // Логика подхвата ответа: ваш сайт должен отдавать массив ссылок или прямую видео-ссылку
            if(json && (json.data || json.video_url)){
                this.activity.loader(false)
                
                // Формируем карточку видео-файла для плеера Lampa
                let file_title = object.movie.title || object.search
                let video_stream = json.video_url || (json.data && json.data[0] ? json.data[0].file_url : '')
                
                if(!video_stream) {
                    this.empty('Ссылка на видеопоток пуста в ответе сайта.')
                    return
                }

                let item = Lampa.Template.get('online', {
                    title: file_title,
                    quality: json.quality || '1080p',
                    info: ''
                })

                item.on('hover:enter', () => {
                    // Запуск встроенного видеоплеера Лампы при клике
                    Lampa.Player.play({
                        url: video_stream,
                        title: file_title
                    })
                    Lampa.Player.callback(() => {
                        Lampa.Controller.toggle('content')
                    })
                }).on('hover:focus', (e) => {
                    scroll.update($(e.target), true)
                })

                scroll.append(item)
                this.loading(false)
                this.start(true)
            } else {
                this.emptyForQuery(object.search)
            }
        }, (a, c) => {
            this.empty('Ошибка подключения к вашему скрытому серверу: ' + network.errorDecode(a, c))
        })
    }

    this.empty = function(msg){
        let empty = Lampa.Template.get('list_empty')
        if(msg) empty.find('.empty__descr').text(msg)
        scroll.append(empty)
        this.loading(false)
    }

    this.emptyForQuery = function(query){
        this.empty(Lampa.Lang.translate('online_query_start') + ' (' + query + ') ' + Lampa.Lang.translate('online_query_end'))
    }

    this.loading = function(status){
        if(status) this.activity.loader(true)
        else {
            this.activity.loader(false)
            this.activity.toggle()
        }
    }

    this.start = function(first_select){
        if(Lampa.Activity.active().activity !== this.activity) return
        let active_card = scroll.render().find('.selector').eq(0)[0]
        Lampa.Background.immediately(Lampa.Utils.cardImgBackground(object.movie))

        Lampa.Controller.add('content',{
            toggle: ()=>{
                Lampa.Controller.collectionSet(scroll.render(), files.render())
                Lampa.Controller.collectionFocus(active_card || false, scroll.render())
            },
            up: ()=>{ if(!Navigator.move('up')) Lampa.Controller.toggle('head') },
            down: ()=>{ Navigator.move('down') },
            right: ()=>{ Navigator.move('right') },
            left: ()=>{ if(!Navigator.move('left')) Lampa.Controller.toggle('menu') },
            back: ()=>{ Lampa.Activity.backward() }
        })
        Lampa.Controller.toggle('content')
    }

    this.render = function(){ return files.render() }
    this.destroy = function(){ network.clear(); files.destroy(); scroll.destroy(); network = null }
}

export default component
