# Sample generator. Takes the _code based simple samples, merges them with
# the standard template and strips out template section markup.

require 'set'

module SampleBuilder
	class Template 
		@@header = nil
		@@header_full = nil
		@@footer = nil
		# TODO(ianbarber): Avoid having 3 identical functions maybe.
		def self.header(site) 
			if @@header.nil?
				@@header = File.read(File.join(site.source, "_includes/sample_header_basic.html"))
			end
			@@header
		end

		def self.header_full(site) 
			if @@header_full.nil?
				@@header_full = File.read(File.join(site.source, "_includes/sample_header_full.html"))
			end
			@@header_full
		end

		def self.footer(site) 
			if @@footer.nil?
				@@footer = File.read(File.join(site.source, "_includes/sample_footer.html"))
			end
			@@footer
		end
	end

	class SampleFile < Jekyll::StaticFile
		def initialize(site, dest, path, file, contents)
			super(site, dest, path, file)
			@contents = contents
			@filename = file
		end

		def filename 
			@filename
		end

  		def write(dest)
  			dest_path = destination(dest)
  			dirname = File.dirname(dest_path)
      		FileUtils.mkdir_p(dirname) if !File.exist?(dirname)
			file = File.new(dest_path, "w")
			file.write(@contents)
			file.close
			Jekyll.logger.info dest_path
  			true
  		end
  	end

  	# TODO(ianbarber): This shouldn't really be a Page I think.
	class Sample < Jekyll::Page
    	def initialize(site, sourcepath, dir)
      		@site = site
      		@sourcepath = sourcepath
      		@dir = dir
    	end

    	def contents() 
    		contents = File.read(@sourcepath)
    		contents.gsub!(/<!-- \/\/ \[(?:(?:START)|(?:END)) [^\]]+\] -->\s*\n?/m, "\n")
    		contents.gsub(/<!-- \/\/ \[TEMPLATE ([^\]]+)\] -->\s*\n/m) { |matches| 
    			tag = $1.downcase
    			if (tag == "header_full") 
    				Template.header(@site)
    			elsif (tag == "header")
    				Template.header(@site) + Template.header_full(@site)
    			elsif (tag == "footer")
    				Template.footer(@site)
				else 
					""
				end
    		}
    	end

    	def filename() 
    		# TODO(ianbarber): Include directory in output.
    		File.join(@dir, File.basename(@sourcepath))
    	end
  	end

	class Generator < Jekyll::Generator
		def generate(site)
			gen_dir = "resources/samples"
			pages = []
			dirs = Set.new
			dirPaths = {}
			path = site.source
			target_dir = File.join(site.dest, gen_dir)

			# Look for _code samples.
			site.pages.each do |page|
				dir = File.join(File.dirname(File.join(path, page.path)), "_code")
				if File.exist?(dir)
					dirs.add(dir) 
					dirPaths[dir] = File.dirname(page.path)
				end
			end
			
			dirs.each do |dir|
				Dir.glob(dir + "/*.html").each do |sourcepath| 
					# TODO(ianbarber): This will need to maintain structure!
				  	pages << Sample.new(site, sourcepath, dirPaths[dir])
				end
			end

		  	pages.each do |page|
				filename = page.filename
				dirname = File.dirname(File.join(target_dir, filename))
				location = File.join(gen_dir, filename)
				site.static_files << SampleFile.new(site, site.dest, File.dirname(location), File.basename(filename), page.contents)
		  	end

		  	# Copy static template files.
		  	site.static_files << Jekyll::StaticFile.new(site, path, "resources/samples/css", "base.css")
		end
	end

	class SamplesTag < Liquid::Tag
	    def initialize(tag_name, markup, tokens)
	      super
	    end

	    def render(context)
		   samples = context.registers[:site].static_files.select{|p| p.is_a?(SampleFile) }
		   samples.each{ |sample| render_sample(sample) }.join("\n")
	    end

	    def render_sample(sample)
	      <<-END
	      <p>
	        #{sample.filename()}
	      </p>
	      END
	    end
	end
end

Liquid::Template.register_tag('list_samples', SampleBuilder::SamplesTag)