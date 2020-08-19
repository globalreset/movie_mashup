#!/bin/env ruby

require 'yaml'
require 'net/http'
require 'json'

# ./movie_mashup.rb target_depth <api key>
#    - target depth is a required argument
#    - if you don't have a movies.dat file, you'll need your own api key. Supply it as the second argument

api_key = ARGV[1] 
url= "https://api.themoviedb.org/3/discover/movie?api_key=#{api_key}&language=en-US&sort_by=popularity.desc&include_adult=false&include_video=false&page=1&vote_count.gte=250"
#url="https://api.themoviedb.org/3/discover/movie?api_key=#{api_key}&language=en-US&sort_by=revenue.desc&include_adult=false&include_video=false&primary_release_date.gte=1975-01-01&primary_release_date.lte=2020-08-01&vote_count.gte=200"

movieDb = nil
movieDbProc = nil
if(!File.exists?("movies.dat"))
   movieDb = []
   response = JSON.parse(Net::HTTP.get(URI("#{url}&page=1")))
   pages = response["total_pages"].to_i
   puts response.inspect
   puts "Getting #{pages} pages of movies"
   pages.times { |i|
      if(movieDb.size<5000)
         response["results"].each { |result|
            puts "adding #{result["title"]}"
            movieDb << result["title"]
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
      # nuke one word movies and movies which are all numbers
      if(tokens.size==0 || tokens.size==1 || movieTitleShort =~ /^[0-9:_']+$/)
         nil
      else
         [movieTitle, movieTitleShort, tokens[0].gsub(/\W/,""), tokens[-1].gsub(/\W/,"")]
      end
   }.compact
   File.open("movies_processed.dat", "w") { |fn| fn << YAML::dump(movieDbProc) }
else
   movieDbProc = YAML::load_file("movies_processed.dat")
end


def findMatches(item, movieDbProc, targetDepth, matchSoFar="")
   matches = []
   movieDbProcMinusItem = movieDbProc.collect { |i| i unless (i[0]==item[0])}.compact
   movieDbProcMinusItem.each { |itemNext|
      if(item[0]!=itemNext[0] && itemNext[2]!="" && item[3]==itemNext[2])
         newMatchSoFar = "#{matchSoFar} <=> #{itemNext[0]}"
         puts newMatchSoFar
         if(targetDepth <= 1)
            matches << newMatchSoFar
         else
            matches << findMatches(itemNext, movieDbProcMinusItem, targetDepth-1, newMatchSoFar)
         end
      end
   }
   return matches
end

matches = []
movieDbProc.each { |item|
   matches << findMatches(item, movieDbProc, ARGV[0].to_i - 1, item[0])
}
