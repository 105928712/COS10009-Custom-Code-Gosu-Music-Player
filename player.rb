"""
Copyright (c) 2025 Joey Manani
Permission is hereby granted, free of charge, to any person obtaining a copy to use this software in an educational context without any restrictions.
Additional licensing information can be found at https://cdn.theflyingrat.com/LICENSE

Custom Program Extension - GUI Gosu Music Player 9.1.3D (+Custom Features)

All requirements met:
Album details view with song list and play functionality for individual tracks
Pages for albums with pagination
Album and track classes for better organization.
Dynamic album grid layout with thumbnails.
Gosu graphics for rendering the GUI.

Additional features:
Tab system to switch between albums, genres, and playlist.
Context menu for album actions (add all songs to playlist, reveal in explorer, delete).
Playlist functionality to add songs, play, shuffle, and clear.
Genres tab remembers what was clicked upon navigating away.

Issues:
The way I generated albums.txt, it scanned album folders alphabetically, so track order isn't the same as within the original albums.
When playing a song from the playlist, and then clicking shuffle, the original song's position will be removed from the playlist when the song completes. This can be mitigated by checking the NAME of the song instead of the index, but I ran out of time :(
There's nothing stopping you from adding far too many songs in an album (and hence playlist). Although the requirement says 15, adding more than 20 will cause GUI overflow.
(Fixed) If the user plays a song, then adds one to the playlist, when the playing song is complete, the playlist will be cleared since the logic thinks the playlist finished playing all its songs.
"""



require 'gosu'

module Genre
    Pop, EDM, Rap, RNB, DNB, Various = *1..6
end

#39ff14
#ff10f1
#600422
#874320
#d6bd69
#433826
#fe7910

#0081A7
#00AFB9

# TOP_COLOR = Gosu::Color.argb(0xff_39ff14)  # worst possible color gradient i could find
# BOTTOM_COLOR = Gosu::Color.argb(0xff_874320)

TOP_COLOR = Gosu::Color.argb(0xff_0081A7)
BOTTOM_COLOR = Gosu::Color.argb(0xff_00AFB9)

UI_CONTRASTING = Gosu::Color.argb(0xff_FFFFFF) 
UI_ACCENT = Gosu::Color.argb(0xff_003443) 
UI_ERROR = Gosu::Color.argb(0xff_FF0000)
UI_SHADOW = Gosu::Color.argb(0x33_000000)
UI_CTX = Gosu::Color.argb(0xEE_333333)

UI_TAB_HOVERED = Gosu::Color.argb(0xAA_54F2F2)
UI_TAB = Gosu::Color.argb(0x66_1f1f1f) # semi-transparent black
UI_TAB_SELECTED = Gosu::Color.argb(0xaa_003443) # semi-transparent black for selected tab
UI_TAB_TEXT = Gosu::Color.argb(0xff_000000) # white text for tab labels

module ZOrder
    BACKGROUND, PLAYER, UI = *0..2
end

class Album
  attr_accessor :artist, :title, :year, :genre, :tracks, :image_path, :image, :hovered
  def initialize(artist, title, year, genre, tracks, image_path = nil)
      @artist = artist
      @title = title
      @year = year
      @genre = genre
      @tracks = tracks
      @image = Gosu::Image.new(image_path) if image_path
      @hovered = false
  end
  def hovered?
    @hovered
  end
end

class Track
  attr_accessor :name, :location, :length
  def initialize(name, location, length)
      @name = name
      @location = location
      @length = length
  end
end


class ContextMenu
  
  def initialize
    @OPTIONS = ["Add All Songs to Playlist", "Reveal in Explorer", "Delete"]
    @visible = false
    @x = 0
    @y = 0
    @width = 280
    @option_height = 30
    @selected_album = nil
  end

  def show(x, y, album)
    @visible = true
    @x, @y = x, y
    @selected_album = album
  end

  def hide
    @visible = false
    @selected_album = nil
  end

  def visible?
    @visible
  end

  def draw
    return if !@visible 
    Gosu.draw_rect(@x, @y, @width, @option_height * @OPTIONS.size, UI_CTX, 100) # transparency
    
    font = Gosu::Font.new(18)
    # draw ctx menu
    index = 0
    while index < @OPTIONS.size
      option = @OPTIONS[index]
      # offsets from the top left corner which the menu is drawn at (hence add @x by 10 and y + index * @option_height + 5 for padding and how much height i want)
      font.draw_text(option, @x + 10, @y + index * @option_height + 5, 100, 1.5, 1.5, UI_CONTRASTING)
      index += 1
    end
  end

  def clicked_option(mouse_x, mouse_y) # for the context menu
    index = (mouse_y - @y) / @option_height # calculate which option was clicked based on the mouse y position
    return nil if !@visible # we dont care if the menu is not visible
    return nil if mouse_x < @x || mouse_x > @x + @width # out of bounds on x axis
    return nil if index < 0 || index >= @OPTIONS.size # out of bounds
    return @OPTIONS[index]
  end

  def selected_album
    @selected_album
  end
end

class Tab
  attr_reader :label, :x, :y, :width, :height

  def initialize(label, x, y, width, height)
    @label = label
    @x = x
    @y = y
    @width = width
    @height = height
  end

  def draw(selected = false, hovered = false)
    background = selected ? UI_TAB_SELECTED : (hovered ? UI_TAB_HOVERED : UI_TAB)
    Gosu.draw_rect(@x, @y, @width, @height, background, 2)

    font = Gosu::Font.new(20)
    text_width = font.text_width(@label) # how wide is the text bc we want to center it
    font.draw_text(@label, @x + (@width - text_width) / 2, @y + 10, 100, 1, 1, UI_TAB_TEXT) # center the text
  end

  def hovered?(mx, my)
    if mx < @x || mx > @x + @width || my < @y || my > @y + @height
      return false
    end
    return true 
  end

  def clicked?(mx, my)
    hovered?(mx, my)
  end
end



















class MusicPlayerWindow < Gosu::Window

  # constants to be used in the program
  WIDTH = 960
  HEIGHT = 720
  GRID_COLS = 4
  GRID_ROWS = 2
  GRID_PADDING = 30 # space between album thumbnails
  THUMBNAIL_SIZE = 200 # 150 seems small but 200 is too big
  TABS_HEIGHT = 40
  GENRE_NAMES = ["Null", "Pop", "EDM", "Rap", "R&B", "Drum & Bass", "Various"]

  def initialize
    super WIDTH, HEIGHT
    self.caption = "Joey's Music Player"

    @filename = "albums.txt" # hardcoded

    @font = Gosu::Font.new(12)
    @albums = load_albums # load albums from file (albums.txt default)

    @context_menu = ContextMenu.new()
    @selected_album = nil
    @album_view = nil  # display all albums in a grid on initialisation
    @album_page = 0 # current page of albums to display, starts at 0

    @current_track_index = 0
    @playlist = nil
    @playlist_status = false # whether the playlist is currently playing or just an individual song

    @filtered_albums = Array.new() # this will hold the albums filtered by genre

    @status = "Ready"


    # evenly space them
    tab_width = WIDTH / 3
    @tabs = [
      Tab.new("Albums",   0,             HEIGHT - TABS_HEIGHT, tab_width, TABS_HEIGHT),
      Tab.new("Genres",   tab_width,     HEIGHT - TABS_HEIGHT, tab_width, TABS_HEIGHT),
      Tab.new("Playlist", tab_width * 2, HEIGHT - TABS_HEIGHT, tab_width, TABS_HEIGHT)
    ]
    @active_tab = "Albums" # set the default active tab to Albums
  end

  # thanks chatgpt
  def album_at(mx, my, albums = @albums)
    total_width = GRID_COLS * THUMBNAIL_SIZE + (GRID_COLS - 1) * GRID_PADDING
    start_x = (WIDTH - total_width) / 2
    start_y = 60

    per_page = GRID_COLS * GRID_ROWS
    start_index = @album_page * per_page
    end_index = [start_index + per_page, albums.size].min 
  
    i = 0
    while i < (end_index - start_index)
      col = i % GRID_COLS
      row = i / GRID_COLS
      x = start_x + col * (THUMBNAIL_SIZE + GRID_PADDING)
      y = start_y + row * (THUMBNAIL_SIZE + GRID_PADDING + 40)

      albums[i + start_index].hovered = false
  
      if mx.between?(x, x + THUMBNAIL_SIZE) && my.between?(y, y + THUMBNAIL_SIZE)
        albums[i + start_index].hovered = true
        return albums[i + start_index] # return the album at the calculated index
      end
  
      i += 1
    end
  
    nil
  end


  # this one wasnt chatgpt but i used inspiration from above
  def song_at(mx, my, album, x_offset = WIDTH / 2)
    return nil if !album # no album view means no songs to click on
    # calculate the position of songs
    num_tracks = album.tracks.length

    # WIDTH / 4, 180 + index * 35 + 50

    start_x = x_offset # left offset x, default is WIDTH / 2 but for playlist, we want it to be WIDTH / 4 so allow this to be changed
    start_y = 150 # top offset y
    track_height = 25 # height of each track line
    index = 0
    while index < num_tracks
      track_y = start_y + index * track_height
      if mx >= start_x && mx <= start_x + WIDTH / 2 && my >= track_y && my <= track_y + track_height
        return album.tracks[index]
      end
      index += 1
    end
    nil
  end

  
  def play_song(track) # can't reference album from the playlist area so removed it.
    @song_playing = "#{track.name}"
    @song = Gosu::Song.new(track.location) # given a track object, not a track number
    @song.play(false)
  end

  def add_to_playlist(track)
    puts "Adding track #{track.name} to playlist"
    @status = "Added to Playlist"
    if @playlist.nil?
      @playlist = Album.new("Playlist", "My Playlist", "Various", 5, Array.new(), nil) # create a new playlist album if the last album is not the playlist1
    end

    @playlist.tracks << track # add the track to the playlist album
  end

  def play_playlist()
    @current_track_index = 0
    @status = "Playing Playlist"
    play_song(@playlist.tracks[@current_track_index]) if @playlist.tracks.any?
  end

  def shuffle_playlist()
    @status = "Shuffled!"
    if @playlist && @playlist.tracks.any?
      @playlist.tracks.shuffle! # shuffle the tracks in the playlist in place  https://www.geeksforgeeks.org/ruby-array-shuffle-function-2/
    end
  end

  def clear_playlist()
    @status = "Cleared!"
    if @playlist && @playlist.tracks.any?
      @playlist.tracks.clear # clear the tracks in the playlist
    end
  end


  def update
    if @song && (!@song.playing? && !@song.paused?) && @playlist && @playlist.tracks.any? && @playlist_status == true # status check because user can override currently playing track by clicking a track within playlist tab, but doesn't mean they want to play the playlist
      @current_track_index += 1
      if @current_track_index < @playlist.tracks.size
        @status = "Playing Playlist"
        play_song(@playlist.tracks[@current_track_index])
      else
        @status = "Finished"
        @playlist.tracks.clear # clear the playlist when finished
      end
      # remove the just-played track from the playlist
      if @playlist && @playlist.tracks.any? && !@current_track_index.nil?
        @playlist.tracks = @playlist.tracks - [@playlist.tracks[@current_track_index]] # https://stackoverflow.com/a/10034720
      end
    end

    # update the hovered album if we are in the albums tab and not viewing an album
    album_at(mouse_x, mouse_y) if @active_tab == "Albums" && @album_view.nil? 
  end




  def handle_menu_option(option, album)
    puts "Selected #{option} for #{album.title}" # debugging output
  
    case option
    when "Add All Songs to Playlist"
      index = 0
      while index < album.tracks.length
        add_to_playlist(album.tracks[index]) # add each track to the playlist
        index += 1
      end
    when "Reveal in Explorer"
      system("explorer sounds\\#{album.title.gsub(' ', '_')}")
    when "Delete"
      @status = "Deleted"
      # delete the songs?
      @albums.delete(album)
    end
  end



  def draw_player_controls
    # draw the player controls as a banner at the top
    Gosu.draw_rect(0, 0, WIDTH, 30, Gosu::Color.argb(0x99_000000), ZOrder::UI) # semi-transparent black background
    @font.draw_text_rel("#{@status}", WIDTH / 2, 5, ZOrder::UI, 0.5, 0, 2, 2, UI_CONTRASTING) # title
    if @song
      @font.draw_text_rel("#{@song_playing}", 10, 5, ZOrder::UI, 0, 0, 2, 2, UI_CONTRASTING)
      if @song.paused?
        @font.draw_text_rel("Play", WIDTH - 100, 5, ZOrder::UI, 0.5, 0, 2, 2, UI_CONTRASTING) # play icon
      elsif @song.playing?
        @font.draw_text_rel("Pause ", WIDTH - 100, 5, ZOrder::UI, 0.5, 0, 2, 2, UI_CONTRASTING) # pause icon
      else
        @song = nil
        @font.draw_text_rel("Play", WIDTH - 100, 5, ZOrder::UI, 0.5, 0, 2, 2, UI_CONTRASTING) # play icon
      end
      @font.draw_text_rel("Stop", WIDTH - 30, 5, ZOrder::UI, 0.5, 0, 2, 2, UI_CONTRASTING) # play icon
    end
  end




  def draw_album_detail(album)
    @font.draw_text_rel("#{album.title.chomp} (#{GENRE_NAMES[album.genre.to_i].chomp})", WIDTH / 2,                             40, ZOrder::UI, 0.5, 0, 3, 3, UI_CONTRASTING)
    @font.draw_text_rel("#{album.artist}", WIDTH / 2,                       80, ZOrder::UI, 0.5, 0, 2, 2, UI_ACCENT)
    @font.draw_text_rel("Left click to play or right click to add to playlist!", WIDTH / 2,     110, ZOrder::UI, 0.5, 0, 1, 1, UI_ACCENT)
    if album.tracks.length == 0
      @font.draw_text_rel("No tracks available for this album.", WIDTH / 2, 150, ZOrder::UI, 0.5, 0, 2, 2, UI_ERROR)
    end

    # draw the album image
    album.image.draw(WIDTH / 16, 150, ZOrder::UI, 0.5, 0.5) # draw the album image at the center

    index = 0
    while index < album.tracks.length
        track = album.tracks[index]
        @font.draw_text_rel("#{index + 1}. #{track.name} (#{track.length})", WIDTH / 2, 150 + index * 25, ZOrder::UI, 0, 0, 1.7, 1.7, UI_CONTRASTING)
        index = index + 1
    end
    # return button
    @font.draw_text_rel("← Click anywhere to return", WIDTH / 2, 630, ZOrder::UI, 0.5, 0, 1.5, 1.5, UI_ACCENT)
  end


  def draw_playlist
    if @playlist.nil? || @playlist.tracks.empty?
      @font.draw_text_rel("No tracks in playlist.", WIDTH / 2, HEIGHT / 2, 3, 0.5, 0, 2, 2, UI_ERROR)
      return
    end
    @font.draw_text_rel(@playlist.title, WIDTH / 2, 40, 3, 0.5, 0, 3, 3, UI_CONTRASTING)
    @font.draw_text_rel("Click a song to play!", WIDTH / 2, 80, 3, 0.5, 0, 2, 2, UI_ACCENT)
    index = 0
    while index < @playlist.tracks.length
      track = @playlist.tracks[index]
      @font.draw_text_rel("#{index + 1}. #{track.name} (#{track.length})", WIDTH / 4, 150 + index * 25, 3, 0, 0, 1.7, 1.7, UI_CONTRASTING)
      index += 1
    end
    # draw the shuffle button to shuffle the tracks
    @font.draw_text_rel("Shuffle", WIDTH - 200, 590, 3, 0.5, 0, 2, 2, UI_CONTRASTING)
    # draw the play button to play the playlist
    @font.draw_text_rel("Play", WIDTH - 300, 590, 3, 0.5, 0, 2, 2, UI_CONTRASTING)
    # clear playlist
    @font.draw_text_rel("Clear", WIDTH - 100, 590, 3, 0.5, 0, 2, 2, UI_CONTRASTING)
    # return button    
    @font.draw_text_rel("← Click anywhere to return", WIDTH / 2, 630, 3, 0.5, 0, 1.5, 1.5, UI_ACCENT)
  end



  def draw
    draw_background

    if @album_view
      draw_album_detail(@album_view)
    elsif @active_tab == "Genres" && @filtered_albums && @filtered_albums.any?
      draw_albums(@filtered_albums) # draw the albums of the selected genre
    else
      draw_albums if @active_tab == "Albums"
      draw_genres if @active_tab == "Genres"
      draw_playlist if @active_tab == "Playlist"
    end

    draw_tabs(mouse_x, mouse_y) # draw the tabs
    draw_player_controls()
    @context_menu.draw # tell the context menu to draw itself (invisible by default because not right clicked)
  end

  def draw_background
    Gosu.draw_quad(
      0, 0, TOP_COLOR,
      WIDTH, 0, TOP_COLOR,
      0, HEIGHT, BOTTOM_COLOR,
      WIDTH, HEIGHT, BOTTOM_COLOR,
      ZOrder::BACKGROUND
    )
  end


  
  def draw_tabs(mouse_x, mouse_y)
    index = 0
    while index < @tabs.length
      tab = @tabs[index]
      # draw the tab and pass thru params if the current tab is currently active or hovered
      tab.draw(tab.label == @active_tab, tab.hovered?(mouse_x, mouse_y))
      index += 1
    end
  end


  def draw_genres
    @font.draw_text_rel("Genres", WIDTH / 2, 40, 3, 0.5, 0, 3, 3, UI_CONTRASTING)
    @font.draw_text_rel("Click a genre to view albums!", WIDTH / 2, 80, 3, 0.5, 0, 2, 2, UI_ACCENT)
    index = 1 # start from 1 because 0 is null
    while index < GENRE_NAMES.length
      genre_name = GENRE_NAMES[index]
      @font.draw_text_rel(genre_name, WIDTH / 2, 150 + index * 35, 3, 0.5, 0, 2, 2, UI_CONTRASTING)
      index += 1
    end
    if @display_genre_empty
      @font.draw_text_rel("No albums found for this genre.", WIDTH / 2, HEIGHT - 100, 3, 0.5, 0, 2, 2, UI_ERROR)
    end
  end


  def draw_albums(albums = @albums) # support a parameter because we can reuse this for genre sorting
    total_width = GRID_COLS * THUMBNAIL_SIZE + (GRID_COLS - 1) * GRID_PADDING
    start_x = (WIDTH - total_width) / 2
    start_y = 60
  
    per_page = GRID_COLS * GRID_ROWS

    start_index = @album_page * per_page
    end_index = [start_index + per_page, albums.size].min # limit the end index to the size of the albums array to prevent overflow
    # puts(albums.size.to_s)
    # puts(end_index.to_s)

    loop_index = 0
    while loop_index < (end_index - start_index) # subtract offset to prevent running too many times
      album = albums[loop_index + start_index] # add offset to reference correct album
      col = loop_index % GRID_COLS
      row = loop_index / GRID_COLS
  
      x = start_x + col * (THUMBNAIL_SIZE + GRID_PADDING)
      y = start_y + row * (THUMBNAIL_SIZE + GRID_PADDING + 40)
  
      # Shadow
      if album.hovered?
        Gosu.draw_rect(x - 5, y - 5, THUMBNAIL_SIZE + 10, THUMBNAIL_SIZE + 10, UI_TAB_HOVERED, 0)
      else
        Gosu.draw_rect(x - 5, y - 5, THUMBNAIL_SIZE + 10, THUMBNAIL_SIZE + 10, UI_SHADOW, 0) # shadow
      end

      # Thumbnail
      album.image.draw(
        x, y, 1,
        THUMBNAIL_SIZE / album.image.width.to_f,
        THUMBNAIL_SIZE / album.image.height.to_f
      )
  
      # Title and artist text
      @font.draw_text_rel(album.title, x + THUMBNAIL_SIZE / 2, y + THUMBNAIL_SIZE + 5, 2, 0.5, 0, 2, 2, UI_CONTRASTING)
      @font.draw_text_rel(album.artist, x + THUMBNAIL_SIZE / 2, y + THUMBNAIL_SIZE + 35, 2, 0.5, 0, 2, 2, UI_ACCENT)
      


      loop_index += 1

    end

    if @album_page > 0
      @font.draw_text_rel("← Prev", 120, HEIGHT - 100, 3, 0.5, 0, 1.5, 1.5, UI_CONTRASTING)
    end
  
    if end_index < albums.size
      @font.draw_text_rel("Next →", WIDTH - 120, HEIGHT - 100, 3, 0.5, 0, 1.5, 1.5, UI_CONTRASTING)
    end

    if @display_genre && @active_tab == "Genres" # if we are displaying albums by genre
      @font.draw_text_rel("Showing albums for #{@display_genre}", WIDTH / 2, HEIGHT - 150, 3, 0.5, 0, 2, 2, UI_ACCENT)
      @font.draw_text_rel("← Click anywhere to return", WIDTH / 2, 630, 3, 0.5, 0, 1.5, 1.5, UI_ACCENT)
    end
  end

  # checks if the area clicked is within the bounds of the given x, y, x_offset, y_offset
  def area_clicked?(x, y, x_offset, y_offset, mouse_x, mouse_y)
    return mouse_x >= x && mouse_x <= x + x_offset && mouse_y >= y && mouse_y <= y + y_offset
  end
  

  def button_down(id)
    case id
    when Gosu::MsLeft

      # if the context menu is visible, handle its click options
      if @context_menu.visible?
        option = @context_menu.clicked_option(mouse_x, mouse_y)
        handle_menu_option(option, @context_menu.selected_album) if option
        @context_menu.hide
        return # prevent further processing (clicked outside of context menu)
      end

      #puts("Mouse clicked at: #{mouse_x}, #{mouse_y}")
      if @song
        if area_clicked?(820, 3, 73, 22, mouse_x, mouse_y) # left click to play/pause
          if @song.paused?
            @status = "Playing"
            @song.play(false) # resume playing
            return # no further actions required    
          else
            @status = "Paused"
            @song.pause # pause the song
            return # no further actions required
          end
        end
        if area_clicked?(905, 3, 50, 22, mouse_x, mouse_y) # left click to stop
          @status = "Stopped"
          @song.stop # stop the song
          @song = nil # reset the song
          @song_playing = nil # reset the song playing text
          return # no further actions required
        end
      end

      if @active_tab == "Albums" && @album_view == nil
        
        puts("Clicked on album area at: #{mouse_x}, #{mouse_y}")
        if area_clicked?(805, HEIGHT - 100, 70, 15, mouse_x, mouse_y) # next button
          max_page = (@albums.size.to_f / (GRID_COLS * GRID_ROWS)).ceil - 1 # trial and error made it work lol
          @album_page += 1 if @album_page < max_page
          return
        elsif area_clicked?(80, HEIGHT - 100, 75, 15, mouse_x, mouse_y) # prev button
          @album_page -= 1 if @album_page > 0
          return
        end
        
        
        # ok so we clicked somewhere else, so calculate the album at the mouse position
        clicked_album = album_at(mouse_x, mouse_y)
        if clicked_album
          # if we clicked on an album, set it as the selected album
          @album_view = clicked_album
          return
        end
      end

      if @active_tab == "Genres" && @album_view == nil
        # if we clicked on a genre, we want to show the albums of that genre
        #puts "Clicked on genre area at: #{mouse_x}, #{mouse_y}"
        if mouse_y > HEIGHT - TABS_HEIGHT # retain the state of the UI if we tab somewhere else
          skip = true
        end
        genre_index = ((mouse_y - 150) / 35).floor # calculate the genre index based on the mouse y position rounded down
        if genre_index >= 1 && genre_index < GENRE_NAMES.length && @filtered_albums.empty? && !skip # if the genre index is valid and we are not already filtering albums
          # check mouse X
          if mouse_x < WIDTH / 2 - 100 || mouse_x > WIDTH / 2 + 100
            return # clicked outside the relative genre text area
          end
          genre_name = GENRE_NAMES[genre_index]
          puts "Clicked on genre: #{genre_name}"
          # filter albums by genre
          index = 0
          @filtered_albums = Array.new() # reset the filtered albums
          while index < @albums.length
            album = @albums[index]
            if album.genre.to_i == genre_index
              @filtered_albums << album
            end
            index += 1
          end
          if @filtered_albums.empty?
            @display_genre_empty = true
            @display_genre = nil
          else
            @display_genre_empty = false 
            @display_genre = genre_name # set the display genre to the clicked genre
            puts(@display_genre)
          end
        elsif @filtered_albums && @filtered_albums.any? && !skip
          @display_genre_empty = false # reset the flag
          clicked_album = album_at(mouse_x, mouse_y, @filtered_albums)
          if clicked_album
            #puts "Clicked on album: #{clicked_album.title.chomp} in filtered albums."
            @album_view = clicked_album # set the album view to the clicked album
            return
          else
            #puts "Clicked on filtered by genre area but not on an album - bail."
            @filtered_albums = Array.new() # reset the filtered albums if we clicked outside of an album
            @album_view = nil
            @display_genre_empty = false
            @display_genre = nil
          end
        elsif !skip
          #puts "Clicked on genre area out of bounds."
          @filtered_albums = Array.new()
          @album_view = nil
          @display_genre_empty = false
          @display_genre = nil
        end
      end
      

      if @active_tab == "Playlist"
        # if we clicked on the playlist tab, we want to show the playlist
        clicked_song = song_at(mouse_x, mouse_y, @playlist, x_offset = WIDTH / 4)
        if clicked_song
          @status = "Playing"
          @playlist_status = false # just a single song, not the playlist
          play_song(clicked_song) # play the song
        else
          # check if we clicked on the shuffle or play button
          #768, 609
          #puts "Clicked on playlist area at: #{mouse_x}, #{mouse_y}"
          if area_clicked?(640, 585, 50, 40, mouse_x, mouse_y) # play button
            @playlist_status = true # we are playing the playlist, not just a single song
            play_playlist()
            return
          elsif area_clicked?(735, 585, 55, 40, mouse_x, mouse_y) # shuffle button
            shuffle_playlist()
            return
          elsif area_clicked?(815, 585, 90, 40, mouse_x, mouse_y) # clear playlist button
            clear_playlist()
            return
          end


          @album_view = nil  # if we clicked on the album view but not on a song, reset the album view
          @active_tab = "Albums" 
        end
      end


      if (@active_tab == "Albums" || @active_tab == "Genres") && @album_view
        clicked_song = song_at(mouse_x, mouse_y, @album_view)
        if clicked_song
          puts "Clicked on song: #{clicked_song.name} at location: #{clicked_song.location}"
          @status = "Playing"
          play_song(clicked_song) # play song 
        else
          @album_view = nil  # if we clicked on the album view but not on a song, reset the album view
        end
      end

      # change the active tab if we clicked on one of the tabs
      index = 0
      while index < @tabs.length
        tab = @tabs[index]
        if tab.clicked?(mouse_x, mouse_y)
          @active_tab = tab.label # set the active tab to the one clicked
          @album_view = nil # reset the album view when switching tabs
        end
        index += 1
      end
  

    when Gosu::MsRight
      if @active_tab == "Albums" && @album_view == nil
        clicked_album = album_at(mouse_x, mouse_y)
        @context_menu.show(mouse_x, mouse_y, clicked_album) if clicked_album
      end

      if (@active_tab == "Albums" || @active_tab == "Genres") && @album_view
        clicked_song = song_at(mouse_x, mouse_y, @album_view)
        if clicked_song
          puts "Clicked on song: #{clicked_song.name} at location: #{clicked_song.location}"
          add_to_playlist(clicked_song) # add the song to the playlist
        end
      end
    end
  end







  def load_albums
    # filename = read_string("Please enter the name of the file to read from:")
    # if !File.exist?(filename)
    #     read_string("File does not exist. Press enter to continue")
    #     return
    # end
    if !File.exist?(@filename)
        puts("File does not exist. Program will now exit.")
        exit(1) # exit the program if the file does not exist
        return
    end
    album_file = File.new(@filename, "r")
    num_albums = album_file.gets().to_i()
    index = 0
    albums = Array.new()
    while index < num_albums
        album = read_album(album_file)
        albums << album
        index = index + 1
    end
    album_file.close()
    return albums
    # index, artist, title, year, genre, tracks, image_path, image
  end

  # Reads in and returns a single album from the given file, with all its tracks
  def read_album(album_file)
    album_artist = album_file.gets()
    album_title = album_file.gets()
    album_year = album_file.gets()
    album_genre = album_file.gets()
    album_image_path = album_file.gets().chomp
    album_tracks = read_tracks(album_file) # also reads number of tracks

    album = Album.new(album_artist, album_title, album_year, album_genre, album_tracks, album_image_path)
    return album
  end

  # Returns an array of tracks read from the given file
  def read_tracks(album_file)
    tracks_count = album_file.gets().to_i() 
    tracks = Array.new()
    index = 0

    # Loop to read the tracks from the file
    while index < tracks_count
        track = read_track(album_file)
        tracks << track
        index = index + 1
    end

    return tracks
  end

  # Reads in a single track from the given file.
  def read_track(album_file)
    name = album_file.gets().chomp
    location = album_file.gets().chomp
    length = album_file.gets().chomp
    return Track.new(name, location, length) # no unique song id yet
  end



end

MusicPlayerWindow.new.show
