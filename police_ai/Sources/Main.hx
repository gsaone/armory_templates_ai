// Auto-generated
package ;
class Main {
    public static inline var projectName = 'police_ai';
    public static inline var projectPackage = 'arm';
    public static function main() {
        iron.object.BoneAnimation.skinMaxBones = 8;
        armory.system.Starter.numAssets = 37;
        armory.system.Starter.drawLoading = armory.trait.internal.LoadingScreen.render;
        armory.system.Starter.main(
            'Scene',
            0,
            true,
            true,
            true,
            1024,
            576,
            2,
            true,
            armory.renderpath.RenderPathCreator.get
        );
    }
}
