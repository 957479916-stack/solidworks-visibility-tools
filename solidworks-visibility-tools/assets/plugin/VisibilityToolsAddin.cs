using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using SolidWorks.Interop.sldworks;
using SolidWorks.Interop.swconst;
using SolidWorks.Interop.swpublished;

namespace SwVisibilityTools
{
    [ComVisible(true)]
    [Guid("0C6173E8-A351-4211-80A8-28D8518F7769")]
    [ProgId("SwVisibilityTools.Connect")]
    public sealed class VisibilityToolsAddin : ISwAddin
    {
        private const int CommandGroupId = 20261120;
        private SldWorks app;
        private CommandManager commandManager;

        public bool ConnectToSW(object thisSw, int cookie)
        {
            try
            {
                app = (SldWorks)thisSw;
                app.SetAddinCallbackInfo2(0, this, cookie);
                CreateCommands(cookie);
                return true;
            }
            catch (Exception ex)
            {
                MessageBox.Show("显示工具插件加载失败：\n" + ex.Message, "SolidWorks 显示工具", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return false;
            }
        }

        public bool DisconnectFromSW()
        {
            try
            {
                if (commandManager != null) commandManager.RemoveCommandGroup(CommandGroupId);
            }
            catch { }
            commandManager = null;
            app = null;
            return true;
        }

        public int EnableAssemblyCommand()
        {
            return GetActiveAssembly() == null ? 0 : 1;
        }

        public void ShowAllHiddenComponents()
        {
            try
            {
                ModelDoc2 model = GetActiveAssembly();
                if (model == null) throw new InvalidOperationException("请先打开一个装配体。");
                AssemblyDoc assembly = (AssemblyDoc)model;
                int changed = 0;
                foreach (Component2 component in GetAllComponents(assembly))
                {
                    try
                    {
                        if (component.Visible == (int)swComponentVisibilityState_e.swComponentHidden)
                        {
                            component.Visible = (int)swComponentVisibilityState_e.swComponentVisible;
                            changed++;
                        }
                    }
                    catch { }
                }
                model.GraphicsRedraw2();
                MessageBox.Show(changed == 0 ? "当前装配体没有隐藏零部件。" : "已显示 " + changed + " 个隐藏零部件。",
                    "显示所有隐藏零部件", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "显示失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        public void RestoreAllOpacity()
        {
            try
            {
                ModelDoc2 model = GetActiveAssembly();
                if (model == null) throw new InvalidOperationException("请先打开一个装配体。");
                AssemblyDoc assembly = (AssemblyDoc)model;
                int changed = 0;
                foreach (Component2 component in GetAllComponents(assembly))
                {
                    try
                    {
                        bool componentChanged = false;
                        double[] values = component.GetMaterialPropertyValues2(
                            (int)swInConfigurationOpts_e.swAllConfiguration, null) as double[];
                        if (ClearTransparency(values))
                        {
                            component.SetMaterialPropertyValues2(
                                values, (int)swInConfigurationOpts_e.swAllConfiguration, null);
                            componentChanged = true;
                        }

                        values = component.GetMaterialPropertyValues2(
                            (int)swInConfigurationOpts_e.swThisConfiguration, null) as double[];
                        if (ClearTransparency(values))
                        {
                            component.SetMaterialPropertyValues2(
                                values, (int)swInConfigurationOpts_e.swThisConfiguration, null);
                            componentChanged = true;
                        }

                        values = component.MaterialPropertyValues as double[];
                        if (ClearTransparency(values))
                        {
                            component.MaterialPropertyValues = values;
                            componentChanged = true;
                        }
                        if (componentChanged) changed++;
                    }
                    catch { }
                }
                model.ForceRebuild3(false);
                model.GraphicsRedraw2();
                MessageBox.Show(changed == 0 ? "当前装配体没有组件级透明零部件。" : "已恢复 " + changed + " 个零部件为不透明。",
                    "恢复全部不透明", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, "恢复透明度失败", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private void CreateCommands(int cookie)
        {
            commandManager = app.GetCommandManager(cookie);
            int error = 0;
            CommandGroup group = commandManager.CreateCommandGroup2(
                CommandGroupId, "装配体显示", "显示隐藏零部件并恢复透明度", "", -1, true, ref error);
            int showId = group.AddCommandItem2(
                "显示所有隐藏零部件", -1, "显示当前装配体中所有隐藏组件，不解除压缩", "显示全部", 0,
                "ShowAllHiddenComponents", "EnableAssemblyCommand", 1,
                (int)swCommandItemType_e.swMenuItem | (int)swCommandItemType_e.swToolbarItem);
            int opacityId = group.AddCommandItem2(
                "恢复全部不透明", -1, "清除组件级透明度，保留现有颜色", "恢复不透明", 1,
                "RestoreAllOpacity", "EnableAssemblyCommand", 2,
                (int)swCommandItemType_e.swMenuItem | (int)swCommandItemType_e.swToolbarItem);
            group.HasToolbar = true;
            group.HasMenu = true;
            group.Activate();

            CommandTab tab = commandManager.GetCommandTab((int)swDocumentTypes_e.swDocASSEMBLY, "装配体显示");
            if (tab != null) commandManager.RemoveCommandTab(tab);
            tab = commandManager.AddCommandTab((int)swDocumentTypes_e.swDocASSEMBLY, "装配体显示");
            if (tab != null)
            {
                CommandTabBox box = tab.AddCommandTabBox();
                box.AddCommands(
                    new[] { group.CommandID[showId], group.CommandID[opacityId] },
                    new[] { (int)swCommandTabButtonTextDisplay_e.swCommandTabButton_TextBelow,
                            (int)swCommandTabButtonTextDisplay_e.swCommandTabButton_TextBelow });
            }
        }

        private ModelDoc2 GetActiveAssembly()
        {
            ModelDoc2 model = app == null ? null : app.IActiveDoc2;
            return model != null && model.GetType() == (int)swDocumentTypes_e.swDocASSEMBLY ? model : null;
        }

        private static IEnumerable<Component2> GetAllComponents(AssemblyDoc assembly)
        {
            object[] components = assembly.GetComponents(false) as object[];
            if (components == null) yield break;
            foreach (object item in components)
            {
                Component2 component = item as Component2;
                if (component != null) yield return component;
            }
        }

        private static bool ClearTransparency(double[] values)
        {
            if (values == null || values.Length < 8) return false;
            bool changed = false;
            for (int index = 7; index < values.Length; index += 9)
            {
                if (values[index] <= 0.0001) continue;
                values[index] = 0.0;
                changed = true;
            }
            return changed;
        }
    }
}
