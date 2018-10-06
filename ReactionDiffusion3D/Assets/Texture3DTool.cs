using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Experimental.Rendering;
using Directory = UnityEngine.Windows.Directory;


public class Texture3DTool : EditorWindow
{
    [MenuItem("Custom/3D Texture Tool")]
    public static void ShowWindow()
    {
        GetWindow<Texture3DTool>();
    }

    private void OnGUI()
    {
        if (GUILayout.Button("Do it!"))
        {
            string path = @"Assets/External/BlueNoise/64_64/";//EditorUtility.OpenFolderPanel("Specify path with texture layers", "", "");
            if (!System.IO.Directory.Exists(path))
                return;
            
//            var fullPath = new Uri(path, UriKind.Absolute);
//            var relRoot = new Uri(Directory.localFolder, UriKind.Absolute);
//            path = relRoot.MakeRelativeUri(fullPath).ToString();
//            Debug.Log(path);
            
            var files = System.IO.Directory.GetFiles(path);
            var textures = files
                .Where(file => file.EndsWith("png"))
                .OrderBy(file => int.Parse(Path.GetFileNameWithoutExtension(file).Split('_').Last()))
                .Select(file => (Texture2D) AssetDatabase.LoadAssetAtPath(file, typeof(Texture2D)))
                .Where(t => t != null).ToArray();
            Debug.Log($"Found {textures.Length} textures");
            
            int width = textures[0].width;
            int height = textures[0].height;
            int depth = textures.Length;
            var volumeColors = new Color[width * height * depth];

            for (int layer=0; layer<depth; ++layer)
            {
                if (textures[layer].width != width || textures[layer].height != height)
                    throw new Exception("Not all textures are the same height/width!");
                var layerColors = textures[layer].GetPixels(0);
                Array.Copy(layerColors, 0, volumeColors, width * height * layer, width * height);
            }

            var volumeTex = new Texture3D(width, height, depth, textures[0].format, false);
            volumeTex.SetPixels(volumeColors);
            AssetDatabase.CreateAsset(volumeTex, $"{path}volume.asset");
        }
    }
}
