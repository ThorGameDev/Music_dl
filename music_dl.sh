#!/bin/bash


find_smallest_dim() {
    read -r width <<< $(identify -format "%[fx:w]" "$1")
    read -r height <<< $(identify -format "%[fx:h]" "$1")
    if [ $width -le $height ]; then
        echo "$width"
    else
        echo "$height"
    fi
}

center_crop() {
    # Extract dimensions using identify
    read -r width <<< $(identify -format "%[fx:w]" "$1")
    read -r height <<< $(identify -format "%[fx:h]" "$1")
    
    # Calculate the cropping coordinates for centering the image 
    left_margin=$(( (width / 2) - ($2 / 2)))
    top_margin=$(( (height / 2) - ($3 / 2)))

    convert "$1" -crop "$2"x"$3"+"$left_margin"+"$top_margin" -resize "$2"x"$3" "cover.jpg"
}


read -p "link: " link
read -p "Author: " artist_name

yt-dlp --recode-video webm $link

# Create a subdirectory for original .webm files
mkdir -p webm

# Loop through all .webm files in the current directory
for video_file in *.webm; do
    if [ -e "$video_file" ]; then
        # Move the original .webm to the "webm" subdirectory
        mv "$video_file" webm/
        # Extract the first frame and save it as cover.jpg
        ffmpeg -i "webm/$video_file" -vf "select=eq(n\,0)" -q:v 3 -vframes 1 "cover_0.jpg"
        
        #Crop the cover
        # Determine the minimum dimension (assuming it's either width or height)
        min_dim=$(find_smallest_dim "cover_0.jpg")
        min_dim=1080
        
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "$min_dim"
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

        # Crop to square maintaining aspect ratio
        #center_crop "cover_0.jpg" "$min_dim" "$min_dim"
	cp "cover_0.jpg" "cover.jpg"

        # Convert .webm to .mp3 with minimal re-compression
        ffmpeg -i "webm/$video_file" -q:a 0 -map a "webm/${video_file%.webm}.mp3"

        # Add cover.jpg as a cover image inside the new .mp3 file
        ffmpeg -i "webm/${video_file%.webm}.mp3" -i "cover.jpg" -map 0 -map 1 -c copy -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" "webm/${video_file%.webm}_with_cover.mp3"

        # Delete cover.jpg
        rm "cover.jpg"
        rm "cover_0.jpg"

        # Set metadata for the new .mp3 file, avoiding square brackets in names
        title_name="${video_file%.webm}"

        # Remove square brackets and their contents from the title and artist
        artist_name=$(echo "$artist_name" | sed 's/\[[^][]*\]//g')
        title_name=$(echo "$title_name" | sed 's/\[[^][]*\]//g')
        title_name=${title_name% *}

        # Set metadata for the new .mp3 file
        ffmpeg -i "webm/${video_file%.webm}_with_cover.mp3" -metadata artist="$artist_name" -metadata title="$title_name" -c copy "${video_file%.webm}_final.mp3"

        # Move the final .mp3 file to the current directory
        mv "${video_file%.webm}_final.mp3" "./${title_name}.mp3"

        # Optionally, remove intermediate files
        rm "webm/${video_file%.webm}.mp3" "webm/${video_file%.webm}_with_cover.mp3"
    fi
done
