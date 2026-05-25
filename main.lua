--[[

    function self:StudioClosedUpdate()
        
        data.UpdateType = "StudioClosed"
        self:UpdateCompiler()
    end
    
    function self:PluginClosedUpdate()
        
        data.UpdateType = "WidgetClosed"
        self:UpdateCompiler()
    end
    
    function self:UserForceUpdate()
        
        data.UpdateType = "ForcedUpdate"
        self:UpdateCompiler()
    end
    
    function self:UserTabUpdate()
        
        data.UpdateType = "TabChange"
        self:UpdateCompiler()
    end

]]

function get