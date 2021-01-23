# mapvideo 

Generate sequential images of map rendering from KML route using Google Map Static API.
According to timestamp of location, you can make realtime based map video.
 
## How to generate map images by frame

```
$ bundle install
$ bundle exec ruby mapvide.rb examples/TimeStamp_example.kml
```


## Make Video

```
$ ffmpeg -r 30 -i image_%03d.png -vcodec libx264 -pix_fmt yuv420p -r 1 out.mp4
```
