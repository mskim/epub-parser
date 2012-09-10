module EPUB
  module Publication
    class Package
      class Metadata
        DC_ELEMS = [:identifiers, :titles, :languages] +
                   [:contributors, :coverages, :creators, :dates, :descriptions, :formats, :publishers,
                    :relations, :rights, :sources, :subjects, :types]
        attr_accessor :package, :unique_identifier, :metas, :links,
                      *(DC_ELEMS.collect {|elem| "dc_#{elem}"})
        DC_ELEMS.each do |elem|
          alias_method elem, "dc_#{elem}"
          alias_method "#{elem}=", "dc_#{elem}="
        end

        def title
          return extended_title unless extended_title.empty?
          compositted = titles.select {|title| title.display_seq}.sort.join("\n")
          return compositted unless compositted.empty?
          return main_title unless main_title.empty?
          titles.sort.join("\n")
        end

        %w[ main short collection edition extended ].each do |type|
          define_method "#{type}_title" do
            titles.select {|title| title.title_type.to_s == type}.sort.join(' ')
          end
        end
        def subtitle
          titles.select {|title| title.title_type.to_s == 'subtitle'}.sort.join(' ')
        end

        def to_hash
          DC_ELEMS.inject({}) do |hsh, elem|
            hsh[elem] = __send__(elem)
            hsh
          end
        end

        def primary_metas
          metas.select {|meta| meta.primary_expression?}
        end

        module Refinable
          attr_writer :refiners

          def refiners
            @refiners ||= []
          end

          PROPERTIES = %w[ alternate-script display-seq file-as group-position identifier-type meta-auth role title-type ]

          PROPERTIES.each do |voc|
            met = voc.gsub(/-/, '_')
            attr_accessor met
            define_method met do
              refiners.select {|refiner| refiner.property == voc}.first
            end
          end
        end

        class Identifier
          include Refinable

          attr_accessor :content, :id

          def to_s
            content
          end
        end

        class Title
          include Refinable
          include Comparable

          attr_accessor :content, :id, :lang, :dir

          def <=>(other)
            return 1 if other.display_seq.nil?
            return -1 if display_seq.nil?
            display_seq.to_s.to_i <=> other.display_seq.to_s.to_i
          end

          def to_s
            content
          end
        end

        class DCMES
          include Refinable

          attr_accessor :content, :id, :lang, :dir

          def to_s
            content
          end
        end

        class Meta
          include Refinable

          attr_accessor :property, :refines, :id, :scheme, :content

          def refines?
            ! refines.nil?
          end

          alias subexpression? refines?

          def primary_expression?
            ! subexpression?
          end

          def to_s
            content
          end
        end

        class Link
          include Refinable

          attr_accessor :href, :rel, :id, :refines, :media_type,
                        :iri
        end
      end
    end
  end
end
