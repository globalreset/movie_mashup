#!/bin/env ruby

require 'yaml'
require 'net/http'
require 'json'

api_key = ARGV[0] 
url= "https://api.themoviedb.org/3/discover/movie?api_key=#{api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=1&vote_count.gte=400"

movieDb = nil
movieDbProc = nil
if(!File.exists?("movies.dat"))
   movieDb = []
   response = JSON.parse(Net::HTTP.get(URI("#{url}&page=1")))
   pages = response["total_pages"].to_i
   puts "Getting #{pages} pages of movies"
   pages.times { |i|
      response["results"].each { |result|
         puts "adding #{result["original_title"]}"
         movieDb << result["original_title"]
      }
      if(i+1<pages)
         begin
            retries ||= 0
            puts "Reading page #{i+1}, try #{retries}"
            system("sleep 0.1")
            response = JSON.parse(Net::HTTP.get(URI("#{url}&page=#{i+1}")))
         rescue
            retry if (retries += 1) < 3
         end
      end
   }
   File.open("movies.dat", "w") { |fn| fn << YAML::dump(movieDb) }
end
if(!File.exists?("movies_processed.dat"))
   movieDb = YAML::load_file("movies.dat")
   puts "processing #{movieDb.size} movies"
   movieDbProc = movieDb.collect{ |movieTitle|
      if(movieTitle =~ /^'(.*)'$/)
         movieTitle = Regexp.last_match(1)
      end
      if(movieTitle =~ /^(.*) [0-9]$/)
         movieTitle = Regexp.last_match(1)
      end
      if(movieTitle =~ /^(.*) I+$/)
         movieTitle = Regexp.last_match(1)
      end
      movieTitle
   }.sort.uniq.collect { |movieTitle|
      # do we ant to include articles or not?
      movieTitleShort = movieTitle#.gsub(/^(A |The |An |And )/,"")
      tokens = movieTitleShort.split(/\W/)
      if(tokens.size==0 || tokens.size==1 || movieTitleShort =~ /^[0-9:]+$/)
         nil
      else
         [movieTitle, movieTitleShort, tokens[0].gsub(/\W/,""), tokens[-1].gsub(/\W/,"")]
      end
   }.compact
   File.open("movies_processed.dat", "w") { |fn| fn << YAML::dump(movieDbProc) }
else
   movieDbProc = YAML::load_file("movies_processed.dat")
end


