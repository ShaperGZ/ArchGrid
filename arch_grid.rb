module ArchProto

  class SiteCell
    attr_accessor :index2
    attr_accessor :position
    attr_accessor :value
    attr_accessor :name
    attr_accessor :grid

    def initialize(iw,ih,grid)
      @index2=[iw,ih]
      @grid=grid
      @value=0.5
    end
  end

  class SiteGrid
    attr_accessor :cells
    attr_accessor :size
    attr_accessor :cell_width
    attr_accessor :base_vect
    attr_accessor :position
    attr_accessor :context
    attr_accessor :subjects
    # attr_accessor :timer

    def initialize(w=10,h=10,cell_width=1.m,position=Geom::Point3d.new(0,0,0))
      @cells={'base'=>[]}
      @cell_width=cell_width
      set_size w,h,false
      set_base_vect Geom::Vector3d.new(1,0,0), false
      set_position position, false
      create_cells(w,h)
      @contenxt=nil
      @subjects=[]
      @timer=nil
    end

    def reset_timer()
      begin
        UI.stop_timer($grid_timer)
      rescue
        p "no existing $timer, start new $timer"
      end

      $grid_timer=UI.start_timer(0.1,true){
        begin
          invalidate
        rescue
          p $!.message
          p $!.backtrace
          UI.stop_timer($grid_timer)
        end
      }
    end

    def stop_timer()
      UI.stop_timer($grid_timer)
    end

    def get_extend_pts()
      # should return min and max points
      # for parent to create bounding box with
      min=@position
      x=@base_x_vect.clone
      y=@base_y_vect.clone
      x.length=@size[0]*@cell_width
      y.length=@size[1]*@cell_width
      max=min+x+y
      return [min,max]
    end

    def set_size(iw,ih,regen_grid=true)
      @size=[iw,ih]
      create_cells(*@size) if regen_grid
    end

    def set_position(val,regen_grid=true)
      @position=val
      create_cells(*@size) if regen_grid
    end

    def add_subject(subject,invalidateFlag=false)
      @subjects<<subject
      invalidate if invalidateFlag
    end

    def add_subjects(subjects,invalidateFlag=false)
      @subjects+=subjects
      invalidate if invalidateFlag
    end

    def invalidate()

    end

    def create_cells(wc,hc)
      keys=@cells.keys
      for k in keys
        icells=[]
        for h in 0..hc-1
          for w in 0..wc-1
            cell=ArchProto::SiteCell.new(w,h,self)
            x=@base_x_vect.clone
            y=@base_y_vect.clone
            x.length=w*@cell_width
            y.length=h*@cell_width
            cell.position=@position+x+y
            d=cell.position.distance(Geom::Point3d.new(0,0,0))/20.m
            d=1 if d>1
            cell.value=1-d.abs
            icells<<cell
          end
        end
        @cells[k]=icells
      end
      @size=[w,h]
    end

    def set_base_vect(val,regen_grid=true)
      @base_vect=val
      @base_x_vect=val.clone
      @base_x_vect.length=@cell_width
      @base_y_vect=Geom::Vector3d.new(0,0,1).cross(@base_x_vect)
      @base_y_vect.length=@cell_width

      create_cells(*@size) if regen_grid
    end

    def on_draw(view)
      for cs in @cells.values
        for c in cs
          # p "#{c.index2} pos:#{c.position}"
          pts=[nil]*4
          pts[0]=c.position
          pts[1]=pts[0]+@base_y_vect
          pts[2]=pts[1]+@base_x_vect
          pts[3]=pts[0]+@base_x_vect
          # fill
          view.drawing_color=Sketchup::Color.new(200,220,255)
          view.draw(GL_QUADS,pts)
          # outline
          view.line_stipple=''#solid line
          view.drawing_color=Sketchup::Color.new(0,0,0)
          view.draw(GL_LINE_LOOP,pts)
        end
      end
    end

    def update_model
      @container=Sketchup.active_model.entities.add_group if @container == nil or !@container.valid?
      @container.entities.clear!
      @container.material=Sketchup::Color.new(200,255,200)

      mesh=Geom::PolygonMesh.new

      for cs in @cells.values
        for c in cs
          next if c.value==0
          # p "#{c.index2} pos:#{c.position}"
          x=@base_x_vect.clone
          y=@base_y_vect.clone
          w=c.value * @cell_width
          x.length=w
          y.length=w
          pts=[nil]*4
          pts[0]=c.position
          pts[1]=pts[0]+y
          pts[2]=pts[1]+x
          pts[3]=pts[0]+x
          mesh.add_polygon(pts)
        end
      end
      @container.entities.add_faces_from_mesh(mesh,0)
      # @container.entities.each{|e| e.hidden=true if e.is_a? Sketchup::Edge}

    end

    def get(iw,ih=nil)
      if ih!=nil
        wCount=size[0]
        index=ih*wCount+iw
      else
        index=iw
      end
      return @cells[index]
    end
  end

  class GInfluence < ArchProto::SiteGrid
    attr_accessor :max_dist
    def initialize(max_dist=20.m,w=10,h=10,cell_width=1.m,position=Geom::Point3d.new(0,0,0))
      super(w,h,cell_width,position)
      @max_dist = max_dist
    end

    def invalidate(update_model_flag=true)
      # p "invalidating GInfluence"
      for cell in @cells['base']
        cell.value=0.1
        for s in @subjects
          distance=s.transformation.origin.distance(cell.position)
          d=distance/@max_dist
          d=1 if d>1
          d=0.1 if d<0.1
          d=1-d
          cell.value=d if d>cell.value
        end
      end
      update_model if update_model_flag
    end
  end

end





sel=Sketchup.active_model.selection.to_a

$grid=ArchProto::GInfluence.new(4.m,20,20,1.m)
$grid.add_subjects(sel)
$grid.invalidate
$grid.reset_timer
# $grid.update_model
# $ad=ArchDisplay.new()
# $ad.add $grid
# Sketchup.active_model.select_tool($ad)
