module EPUB
  module Publication
    module FixedLayout
      PREFIX_KEY = 'rendition'
      PREFIX_VALUE = 'http://www.idpf.org/vocab/rendition/#'

      RENDITION_PROPERTIES = {
        'layout'      => ['reflowable'.freeze, 'pre-paginated'.freeze].freeze,
        'orientation' => ['auto'.freeze, 'landscape'.freeze, 'portrait'.freeze].freeze,
        'spread'      => ['auto'.freeze, 'none'.freeze, 'landscape'.freeze, 'portrait'.freeze, 'both'.freeze].freeze
      }.freeze

      class UnsupportedRenditionValue < StandardError; end

      class << self
        def included(package_class)
          [
           [Package, PackageMixin],
           [Package::Metadata, MetadataMixin],
           [Package::Spine::Itemref, ItemrefMixin],
           [Package::Manifest::Item, ItemMixin],
           [ContentDocument, ContentDocumentMixin],
          ].each do |(base, mixin)|
            base.module_eval do
              include mixin
            end
          end
        end
      end

      module Rendition
        def def_rendition_methods
          RENDITION_PROPERTIES.each_key do |property|
            alias_method property, "rendition_#{property}"
            alias_method "#{property}=", "rendition_#{property}="
          end
          def_rendition_layout_methods
        end

        def def_rendition_layout_methods
          property = 'layout'
          RENDITION_PROPERTIES[property].each do |value|
            method_name_base = value.gsub('-', '_')
            writer_name = "#{method_name_base}="
            define_method writer_name do |new_value|
              new_prop = new_value ? value : values.find {|l| l != value}
              __send__ "rendition_#{property}=", new_prop
            end

            maker_name = "make_#{method_name_base}"
            define_method maker_name do
              __send__ "rendition_#{property}=", value
            end
            destructive_method_name = "#{method_name_base}!"
            alias_method destructive_method_name, maker_name

            predicate_name = "#{method_name_base}?"
            define_method predicate_name do
              __send__("rendition_#{property}") == value
            end
          end
        end
      end

      module PackageMixin
        def using_fixed_layout
          prefix.has_key? PREFIX_KEY and
            prefix[PREFIX_KEY] == PREFIX_VALUE
        end
        alias using_fixed_layout? using_fixed_layout

        # @param using_fixed_layout [true, false]
        def using_fixed_layout=(using_fixed_layout)
          if using_fixed_layout
            prefix[PREFIX_KEY] = PREFIX_VALUE
          else
            prefix.delete PREFIX_KEY
          end
        end
      end

      module MetadataMixin
        extend Rendition

        RENDITION_PROPERTIES.each_pair do |property, values|
          define_method "rendition_#{property}" do
            meta = metas.find {|m| m.property == "rendition:#{property}"}
            meta ? meta.content : values.first
          end

          define_method "rendition_#{property}=" do |new_value|
            raise UnsupportedRenditionValue, new_value unless values.include? new_value

            prefixed_property = "rendition:#{property}"
            values_to_be_deleted = values - [new_value]
            metas.delete_if {|meta| meta.property == prefixed_property && values_to_be_deleted.include?(meta.content)}
            unless metas.any? {|meta| meta.property == prefixed_property && meta.content == new_value}
              meta = Package::Metadata::Meta.new
              meta.property = prefixed_property
              meta.content = new_value
              metas << meta
            end
            new_value
          end
        end

        def_rendition_methods
      end

      module ItemrefMixin
        extend Rendition

        RENDITION_LAYOUT_PREFIX = 'rendition:layout-'

        RENDITION_PROPERTIES.each do |property, values|
          rendition_property_prefix = "rendition:#{property}-"

          reader_name = "rendition_#{property}"
          define_method reader_name do
            prop_value = properties.find {|prop| prop.start_with? rendition_property_prefix}
            prop_value ? prop_value.gsub(/\A#{Regexp.escape(rendition_property_prefix)}/o, '') :
              spine.package.metadata.__send__(reader_name)
          end

          writer_name = "#{reader_name}="
          define_method writer_name do |new_value|
            if new_value.nil?
              properties.delete_if {|prop| prop.start_with? rendition_property_prefix}
              return new_value
            end

            raise UnsupportedRenditionValue, new_value unless values.include? new_value

            values_to_be_deleted = (values - [new_value]).map {|value| "#{rendition_property_prefix}#{value}"}
            properties.delete_if {|prop| values_to_be_deleted.include? prop}
            new_property = "#{rendition_property_prefix}#{new_value}"
            properties << new_property unless properties.any? {|prop| prop == new_property}
            new_value
          end
        end

        def_rendition_methods
      end

      module ItemMixin
        
      end

      module ContentDocumentMixin
        
      end
    end
  end
end
